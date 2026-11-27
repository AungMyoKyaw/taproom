import Foundation
import Testing
@testable import Taproom

private final class StubBrewRunner: BrewExecutable, @unchecked Sendable {
    let brewPath = "/opt/homebrew/bin/brew"
    let prefixPath = "/opt/homebrew"
    private let lock = NSLock()
    private var _recordedRunArgs: [[String]] = []
    private var _recordedStreamArgs: [[String]] = []

    var recordedRunArgs: [[String]] { lock.withLock { _recordedRunArgs } }
    var recordedStreamArgs: [[String]] { lock.withLock { _recordedStreamArgs } }
    var responses: [String: BrewCommandOutput] = [:]

    func run(args: [String]) async throws -> BrewCommandOutput {
        lock.withLock { _recordedRunArgs.append(args) }
        if let first = args.first, let custom = responses[first] {
            return custom
        }
        return BrewCommandOutput(stdout: "", stderr: "", exitCode: 0)
    }

    func stream(args: [String], onLine: @escaping @Sendable (String) -> Void) async throws -> (handle: BrewRunningHandle, completion: Task<Int32, Error>) {
        lock.withLock { _recordedStreamArgs.append(args) }
        struct NoopHandle: BrewRunningHandle { func cancel() {} }
        let task = Task<Int32, Error> { 0 }
        return (NoopHandle(), task)
    }
}

@Suite("AppState Tests")
@MainActor
struct AppStateTests {
    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suite = "dev.taproom.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    @Test("Persists settings across AppState instances via UserDefaults")
    func settingsPersistence() throws {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let catalog = try CatalogStore(inMemory: true)
        let first = AppState(runner: StubBrewRunner(), userDefaults: defaults, catalog: catalog)
        first.checkIntervalHours = 12
        first.notifyOnOutdated = false
        first.includeGreedyCasks = true

        let second = AppState(runner: StubBrewRunner(), userDefaults: defaults, catalog: catalog)
        #expect(second.checkIntervalHours == 12)
        #expect(second.notifyOnOutdated == false)
        #expect(second.includeGreedyCasks == true)
    }

    @Test("Passes --greedy on outdated refresh and surfaces non-zero command errors")
    func greedyRefreshAndErrorReporting() async throws {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let runner = StubBrewRunner()
        runner.responses["info"] = BrewCommandOutput(
            stdout: """
            {"formulae":[{"name":"ripgrep","full_name":"ripgrep","tap":"homebrew/core","desc":"Search","homepage":"https://example.com","license":"MIT","versions":{"stable":"14.1.1"},"installed":[{"version":"14.1.1","installed_on_request":true}],"dependencies":["pcre2"],"caveats":null,"pinned":false},{"name":"pcre2","full_name":"pcre2","tap":"homebrew/core","desc":"Regex","homepage":"https://example.com","license":"BSD","versions":{"stable":"10.45"},"installed":[{"version":"10.45","installed_on_request":false}],"dependencies":[],"caveats":null,"pinned":false}],"casks":[]}
            """,
            stderr: "",
            exitCode: 0
        )
        runner.responses["outdated"] = BrewCommandOutput(stdout: "", stderr: "network timeout", exitCode: 1)
        runner.responses["services"] = BrewCommandOutput(stdout: "[]", stderr: "", exitCode: 0)
        runner.responses["tap-info"] = BrewCommandOutput(stdout: "[]", stderr: "", exitCode: 0)
        runner.responses["--version"] = BrewCommandOutput(stdout: "Homebrew 4.4.0\n", stderr: "", exitCode: 0)

        let state = AppState(runner: runner, userDefaults: defaults, catalog: try CatalogStore(inMemory: true))
        state.includeGreedyCasks = true
        await state.refreshAll()

        #expect(runner.recordedRunArgs.contains(["outdated", "--json=v2", "--greedy"]))
        #expect(state.lastError?.contains("brew outdated: network timeout") == true)
        #expect(state.dependents(of: "pcre2").map(\.name) == ["ripgrep"])

        state.dismissError()
        #expect(state.lastError == nil)
    }

    @Test("Enqueues --zap only for casks and ignores zap for formulae")
    func uninstallZapArguments() async throws {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let runner = StubBrewRunner()
        let state = AppState(runner: runner, userDefaults: defaults, catalog: try CatalogStore(inMemory: true))

        let cask = BrewPackage(
            id: "cask:ghostty", name: "ghostty", fullName: "ghostty", kind: .cask,
            version: "1.1.3", tap: "homebrew/cask", description: "", homepage: "",
            license: nil, installedOnRequest: true, pinned: false, dependencies: [],
            caveats: nil, installedPath: nil, diskSizeBytes: nil
        )
        let formula = BrewPackage(
            id: "formula:jq", name: "jq", fullName: "jq", kind: .formula,
            version: "1.7.1", tap: "homebrew/core", description: "", homepage: "",
            license: nil, installedOnRequest: true, pinned: false, dependencies: [],
            caveats: nil, installedPath: nil, diskSizeBytes: nil
        )

        state.uninstallPackage(cask, zap: true)
        state.uninstallPackage(formula, zap: true)

        for _ in 0..<40 {
            if !state.queue.isProcessing && state.queue.jobs.allSatisfy({ $0.state.isTerminal }) { break }
            try await Task.sleep(for: .milliseconds(15))
        }

        #expect(runner.recordedStreamArgs == [
            ["uninstall", "--cask", "--zap", "ghostty"],
            ["uninstall", "jq"]
        ])
    }

    @Test("Enqueues adopt and missing commands and records operation history")
    func adoptMissingAndHistory() async throws {
        let (defaults, suite) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let runner = StubBrewRunner()
        let state = AppState(runner: runner, userDefaults: defaults, catalog: try CatalogStore(inMemory: true))
        state.customBrewPath = "/opt/custom/bin/brew"
        state.httpProxy = "http://127.0.0.1:8080"

        let app = DiscoveredApp(
            id: "/Applications/Raycast.app",
            name: "Raycast",
            bundleIdentifier: "com.raycast.macos",
            version: "1.80.0",
            path: "/Applications/Raycast.app",
            architecture: .arm64,
            matchedCaskToken: "raycast",
            isManagedByBrew: false
        )
        state.adoptApp(app)
        state.runMissingCheck()

        for _ in 0..<40 {
            if !state.queue.isProcessing && state.queue.jobs.allSatisfy({ $0.state.isTerminal }) { break }
            try await Task.sleep(for: .milliseconds(15))
        }

        #expect(runner.recordedStreamArgs == [
            ["install", "--cask", "--adopt", "raycast"],
            ["missing"]
        ])
        #expect(state.operationHistory.count == 2)

        let reloaded = AppState(runner: runner, userDefaults: defaults, catalog: try CatalogStore(inMemory: true))
        #expect(reloaded.customBrewPath == "/opt/custom/bin/brew")
        #expect(reloaded.httpProxy == "http://127.0.0.1:8080")
        #expect(reloaded.operationHistory.count == 2)

        reloaded.clearOperationHistory()
        #expect(reloaded.operationHistory.isEmpty)
    }
}
