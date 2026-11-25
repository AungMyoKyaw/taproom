import Foundation
import Testing
@testable import Taproom

private final class MockRunningHandle: BrewRunningHandle, @unchecked Sendable {
    var cancelled = false
    func cancel() { cancelled = true }
}

private final class MockBrewRunner: BrewExecutable, @unchecked Sendable {
    let brewPath = "/opt/homebrew/bin/brew"
    let prefixPath = "/opt/homebrew"
    private let lock = NSLock()
    private var _executedArgs: [[String]] = []
    var executedArgs: [[String]] {
        lock.withLock { _executedArgs }
    }
    var exitCodeToReturn: Int32 = 0

    func run(args: [String]) async throws -> BrewCommandOutput {
        BrewCommandOutput(stdout: "", stderr: "", exitCode: 0)
    }

    func stream(args: [String], onLine: @escaping @Sendable (String) -> Void) async throws -> (handle: BrewRunningHandle, completion: Task<Int32, Error>) {
        lock.withLock { _executedArgs.append(args) }
        let handle = MockRunningHandle()
        let code = exitCodeToReturn
        let task = Task<Int32, Error> {
            onLine("running \(args.joined(separator: " "))")
            try? await Task.sleep(for: .milliseconds(30))
            return handle.cancelled ? 130 : code
        }
        return (handle, task)
    }
}

@Suite("MutationQueue FIFO Tests")
@MainActor
struct MutationQueueTests {
    @Test("Executes queued jobs in strict FIFO order and calls onDrain")
    func fifoExecutionOrder() async throws {
        let mock = MockBrewRunner()
        var drained = false
        let queue = MutationQueue(runner: mock) {
            drained = true
        }

        let j1 = queue.enqueue(title: "Install jq", args: ["install", "jq"])
        let j2 = queue.enqueue(title: "Install fzf", args: ["install", "fzf"])

        // Wait until queue finishes both jobs
        for _ in 0..<50 {
            if !queue.isProcessing && drained { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(mock.executedArgs == [["install", "jq"], ["install", "fzf"]])
        #expect(queue.jobs.first { $0.id == j1 }?.state == .succeeded)
        #expect(queue.jobs.first { $0.id == j2 }?.state == .succeeded)
        #expect(drained == true)
    }

    @Test("Cancelling queued job prevents execution while next job runs")
    func cancelQueuedJob() async throws {
        let mock = MockBrewRunner()
        let queue = MutationQueue(runner: mock)

        let j1 = queue.enqueue(title: "First", args: ["install", "a"])
        let j2 = queue.enqueue(title: "Second", args: ["install", "b"])
        queue.cancel(jobID: j2)

        for _ in 0..<50 {
            if queue.jobs.first(where: { $0.id == j1 })?.state.isTerminal == true { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(mock.executedArgs == [["install", "a"]])
        #expect(queue.jobs.first { $0.id == j1 }?.state == .succeeded)
        #expect(queue.jobs.first { $0.id == j2 }?.state == .cancelled)
    }
}
