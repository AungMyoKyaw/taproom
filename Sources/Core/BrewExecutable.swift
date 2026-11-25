import Foundation

struct BrewCommandOutput: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

protocol BrewRunningHandle: Sendable {
    func cancel()
}

protocol BrewExecutable: Sendable {
    var brewPath: String { get }
    var prefixPath: String { get }
    func run(args: [String]) async throws -> BrewCommandOutput
    func stream(args: [String], onLine: @escaping @Sendable (String) -> Void) async throws -> (handle: BrewRunningHandle, completion: Task<Int32, Error>)
}

enum BrewRunnerError: Error, LocalizedError {
    case brewNotFound
    case commandFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            "Homebrew binary not found at /opt/homebrew/bin/brew or /usr/local/bin/brew."
        case .commandFailed(let code, let detail):
            "brew exited with status \(code): \(detail)"
        }
    }
}

private final class LockedDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ newData: Data) {
        lock.withLock { data = newData }
    }

    func get() -> Data {
        lock.withLock { data }
    }
}

private final class ProcessHandle: BrewRunningHandle, @unchecked Sendable {
    private let process: Process
    init(_ process: Process) { self.process = process }

    func cancel() {
        guard process.isRunning else { return }
        process.interrupt()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [process] in
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

final class LiveBrewRunner: BrewExecutable, @unchecked Sendable {
    let brewPath: String
    let prefixPath: String
    private let askpassPath: String?
    private let envLock = NSLock()
    private var cachedShellEnv: [String: String]?

    init() {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        let found = candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/brew"
        self.brewPath = found
        self.prefixPath = found.hasPrefix("/opt/homebrew") ? "/opt/homebrew" : "/usr/local"
        self.askpassPath = AskpassHelper.ensureScriptPath()
    }

    private func loadLoginShellEnv() -> [String: String] {
        envLock.lock()
        if let cached = cachedShellEnv {
            envLock.unlock()
            return cached
        }
        envLock.unlock()

        let captured = Self.captureLoginShellVariables()
        envLock.lock()
        if cachedShellEnv == nil {
            cachedShellEnv = captured
        }
        let result = cachedShellEnv ?? captured
        envLock.unlock()
        return result
    }

    private static func captureLoginShellVariables() -> [String: String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-lc", "env"]
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice
        proc.standardInput = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return [:]
        }

        let box = LockedDataBox()
        let sema = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            box.set(outPipe.fileHandleForReading.readDataToEndOfFile())
            proc.waitUntilExit()
            sema.signal()
        }
        if sema.wait(timeout: .now() + 1.5) == .timedOut {
            if proc.isRunning { proc.terminate() }
            return [:]
        }

        let allowedProxyKeys: Set<String> = [
            "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
            "http_proxy", "https_proxy", "all_proxy", "no_proxy"
        ]
        var vars: [String: String] = [:]
        let text = String(decoding: box.get(), as: UTF8.self)
        for line in text.split(whereSeparator: \.isNewline) {
            guard let eqIdx = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eqIdx])
            let value = String(line[line.index(after: eqIdx)...])
            if key.hasPrefix("HOMEBREW_") || allowedProxyKeys.contains(key) {
                vars[key] = value
            }
        }
        return vars
    }

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for (key, value) in loadLoginShellEnv() {
            env[key] = value
        }
        let extraPath = "\(prefixPath)/bin:\(prefixPath)/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
        if let existing = env["PATH"], !existing.isEmpty {
            env["PATH"] = "\(extraPath):\(existing)"
        } else {
            env["PATH"] = extraPath
        }
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["HOMEBREW_NO_COLOR"] = "1"
        if let askpassPath {
            env["SUDO_ASKPASS"] = askpassPath
        }
        return env
    }

    func run(args: [String]) async throws -> BrewCommandOutput {
        guard FileManager.default.isExecutableFile(atPath: brewPath) else {
            throw BrewRunnerError.brewNotFound
        }
        let executable = brewPath

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let env = self.buildEnvironment()
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = args
                proc.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe
                proc.standardInput = FileHandle.nullDevice

                do {
                    try proc.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Read stdout and stderr concurrently before waitUntilExit to avoid pipe deadlocks.
                let outBox = LockedDataBox()
                let errBox = LockedDataBox()
                let group = DispatchGroup()

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile())
                    group.leave()
                }
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
                    group.leave()
                }

                group.wait()
                proc.waitUntilExit()

                let output = BrewCommandOutput(
                    stdout: String(decoding: outBox.get(), as: UTF8.self),
                    stderr: String(decoding: errBox.get(), as: UTF8.self),
                    exitCode: proc.terminationStatus
                )
                continuation.resume(returning: output)
            }
        }
    }

    func stream(
        args: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async throws -> (handle: BrewRunningHandle, completion: Task<Int32, Error>) {
        guard FileManager.default.isExecutableFile(atPath: brewPath) else {
            throw BrewRunnerError.brewNotFound
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: brewPath)
        proc.arguments = args
        proc.environment = buildEnvironment()

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        proc.standardInput = FileHandle.nullDevice

        let handle = ProcessHandle(proc)
        try proc.run()

        let completion = Task.detached(priority: .userInitiated) { () throws -> Int32 in
            let fh = pipe.fileHandleForReading
            var buffer = Data()
            while true {
                let chunk = fh.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let nlIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[..<nlIndex]
                    buffer.removeSubrange(...nlIndex)
                    let line = String(decoding: lineData, as: UTF8.self)
                    onLine(line)
                }
            }
            if !buffer.isEmpty {
                onLine(String(decoding: buffer, as: UTF8.self))
            }
            proc.waitUntilExit()
            return proc.terminationStatus
        }

        return (handle, completion)
    }
}
