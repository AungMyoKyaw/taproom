import Foundation
import Observation

@MainActor
@Observable
final class MutationQueue {
    private(set) var jobs: [MutationJob] = []
    private(set) var isProcessing: Bool = false

    private let runner: BrewExecutable
    private var activeHandle: BrewRunningHandle?
    private var activeJobID: UUID?
    private var onDrain: (@MainActor @Sendable () async -> Void)?

    init(runner: BrewExecutable, onDrain: (@MainActor @Sendable () async -> Void)? = nil) {
        self.runner = runner
        self.onDrain = onDrain
    }

    func setOnDrain(_ handler: @escaping @MainActor @Sendable () async -> Void) {
        self.onDrain = handler
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
            let (handle, completion) = try await runner.stream(args: args) { [weak self] line in
                Task { @MainActor [weak self] in
                    guard let self, let idx = self.jobs.firstIndex(where: { $0.id == jobID }) else { return }
                    self.jobs[idx].logLines.append(line)
                }
            }
            activeHandle = handle
            let exitCode = try await completion.value
            activeHandle = nil

            if let idx = jobs.firstIndex(where: { $0.id == jobID }) {
                if jobs[idx].state != .cancelled {
                    jobs[idx].state = exitCode == 0 ? .succeeded : .failed("Exited with code \(exitCode)")
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

        if jobs.contains(where: { $0.state == .queued }) {
            await processNext()
        } else {
            await onDrain?()
        }
    }
}
