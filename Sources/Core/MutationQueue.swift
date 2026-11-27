import Foundation
import Observation

private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [String] = []
    private var flushScheduled = false

    func append(_ line: String) -> Bool {
        lock.lock()
        pending.append(line)
        let shouldSchedule = !flushScheduled
        if shouldSchedule {
            flushScheduled = true
        }
        lock.unlock()
        return shouldSchedule
    }

    func drain() -> [String] {
        lock.lock()
        let lines = pending
        pending.removeAll(keepingCapacity: true)
        flushScheduled = false
        lock.unlock()
        return lines
    }
}

@MainActor
@Observable
final class MutationQueue {
    private(set) var jobs: [MutationJob] = []
    private(set) var isProcessing: Bool = false

    private let runner: BrewExecutable
    private var activeHandle: BrewRunningHandle?
    private var activeJobID: UUID?
    private var onDrain: (@MainActor @Sendable () async -> Void)?
    private var onJobFinish: (@MainActor @Sendable (MutationJob) -> Void)?

    init(
        runner: BrewExecutable,
        onDrain: (@MainActor @Sendable () async -> Void)? = nil,
        onJobFinish: (@MainActor @Sendable (MutationJob) -> Void)? = nil
    ) {
        self.runner = runner
        self.onDrain = onDrain
        self.onJobFinish = onJobFinish
    }

    func setOnDrain(_ handler: @escaping @MainActor @Sendable () async -> Void) {
        self.onDrain = handler
    }

    func setOnJobFinish(_ handler: @escaping @MainActor @Sendable (MutationJob) -> Void) {
        self.onJobFinish = handler
    }

    var activeJob: MutationJob? {
        guard let activeJobID else { return nil }
        return jobs.first { $0.id == activeJobID }
    }

    var queuedCount: Int {
        jobs.filter { $0.state == .queued }.count
    }

    @discardableResult
    func enqueue(title: String, args: [String]) -> UUID {
        let job = MutationJob(title: title, args: args)
        jobs.append(job)
        if !isProcessing {
            Task { await processNext() }
        }
        return job.id
    }

    func cancel(jobID: UUID) {
        guard let idx = jobs.firstIndex(where: { $0.id == jobID }) else { return }
        switch jobs[idx].state {
        case .queued:
            jobs[idx].state = .cancelled
            jobs[idx].finishedAt = Date()
            onJobFinish?(jobs[idx])
        case .running:
            activeHandle?.cancel()
            jobs[idx].state = .cancelled
            jobs[idx].finishedAt = Date()
        case .succeeded, .failed, .cancelled:
            break
        }
    }

    func clearFinished() {
        jobs.removeAll { $0.state.isTerminal }
    }

    private func processNext() async {
        guard !isProcessing else { return }
        guard let nextIndex = jobs.firstIndex(where: { $0.state == .queued }) else {
            return
        }

        isProcessing = true
        let jobID = jobs[nextIndex].id
        activeJobID = jobID
        jobs[nextIndex].state = .running
        jobs[nextIndex].startedAt = Date()
        let args = jobs[nextIndex].args
        jobs[nextIndex].logLines.append("$ brew \(args.joined(separator: " "))")

        do {
            let lineBuffer = LineBuffer()
            let (handle, completion) = try await runner.stream(args: args) { [weak self] line in
                if lineBuffer.append(line) {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(50))
                        let batch = lineBuffer.drain()
                        guard !batch.isEmpty, let self, let idx = self.jobs.firstIndex(where: { $0.id == jobID }) else { return }
                        self.jobs[idx].logLines.append(contentsOf: batch)
                    }
                }
            }
            activeHandle = handle
            let exitCode = try await completion.value
            activeHandle = nil

            let remaining = lineBuffer.drain()
            if !remaining.isEmpty, let idx = jobs.firstIndex(where: { $0.id == jobID }) {
                jobs[idx].logLines.append(contentsOf: remaining)
            }

            if let idx = jobs.firstIndex(where: { $0.id == jobID }) {
                if jobs[idx].state != .cancelled {
                    if exitCode == 0 {
                        jobs[idx].state = .succeeded
                    } else if Self.isAuthCancelled(lines: jobs[idx].logLines) {
                        jobs[idx].state = .failed("Authentication cancelled")
                    } else {
                        jobs[idx].state = .failed("Exited with code \(exitCode)")
                    }
                    jobs[idx].finishedAt = Date()
                }
            }
        } catch {
            activeHandle = nil
            if let idx = jobs.firstIndex(where: { $0.id == jobID }), jobs[idx].state != .cancelled {
                jobs[idx].state = .failed(error.localizedDescription)
                jobs[idx].logLines.append("Error: \(error.localizedDescription)")
                jobs[idx].finishedAt = Date()
            }
        }

        activeJobID = nil
        isProcessing = false

        if let finished = jobs.first(where: { $0.id == jobID }) {
            onJobFinish?(finished)
        }

        if jobs.contains(where: { $0.state == .queued }) {
            await processNext()
        } else {
            await onDrain?()
        }
    }

    private static func isAuthCancelled(lines: [String]) -> Bool {
        let markers = [
            "sudo: a password is required",
            "no askpass program",
            "User canceled",
            "(-128)"
        ]
        return lines.contains { line in
            markers.contains { line.localizedCaseInsensitiveContains($0) }
        }
    }
}
