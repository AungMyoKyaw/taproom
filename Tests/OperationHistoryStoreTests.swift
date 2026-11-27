import Foundation
import Testing
@testable import Taproom

@Suite("OperationHistoryStore Tests")
struct OperationHistoryStoreTests {
    @Test("Persists terminal jobs across instances and ignores non-terminal jobs")
    @MainActor
    func persistsTerminalJobsAndClears() {
        let suiteName = "dev.taproom.tests.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = OperationHistoryStore(userDefaults: defaults)

        var runningJob = MutationJob(title: "Running", args: ["doctor"])
        runningJob.state = .running
        store.append(job: runningJob)
        #expect(store.records.isEmpty)

        var okJob = MutationJob(title: "Install jq", args: ["install", "jq"])
        okJob.startedAt = Date(timeIntervalSince1970: 100)
        okJob.finishedAt = Date(timeIntervalSince1970: 103.5)
        okJob.state = .succeeded
        store.append(job: okJob)

        var failJob = MutationJob(title: "Upgrade foo", args: ["upgrade", "foo"])
        failJob.state = .failed("Exited with code 1")
        failJob.finishedAt = Date(timeIntervalSince1970: 200)
        store.append(job: failJob)

        let reloaded = OperationHistoryStore(userDefaults: defaults)
        #expect(reloaded.records.count == 2)
        #expect(reloaded.records[0].title == "Upgrade foo")
        #expect(!reloaded.records[0].succeeded)
        #expect(reloaded.records[1].title == "Install jq")
        #expect(reloaded.records[1].succeeded)
        #expect(reloaded.records[1].durationSeconds == 3.5)

        reloaded.clear()
        #expect(reloaded.records.isEmpty)
    }
}
