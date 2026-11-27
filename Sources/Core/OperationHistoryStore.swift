import Foundation

struct OperationRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let args: [String]
    let succeeded: Bool
    let statusSummary: String
    let finishedAt: Date
    let durationSeconds: TimeInterval
}

@MainActor
final class OperationHistoryStore {
    private let userDefaults: UserDefaults
    private let storageKey = "taproom.operationHistory.v1"
    private let maxRecords = 100

    private(set) var records: [OperationRecord] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.records = Self.load(from: userDefaults, key: storageKey)
    }

    func append(job: MutationJob) {
        let finishedAt = job.finishedAt ?? Date()
        let duration: TimeInterval
        if let started = job.startedAt {
            duration = max(0, finishedAt.timeIntervalSince(started))
        } else {
            duration = 0
        }

        let succeeded: Bool
        let summary: String
        switch job.state {
        case .succeeded:
            succeeded = true
            summary = "Succeeded"
        case .failed(let msg):
            succeeded = false
            summary = msg
        case .cancelled:
            succeeded = false
            summary = "Cancelled"
        case .queued, .running:
            return
        }

        let record = OperationRecord(
            id: job.id,
            title: job.title,
            args: job.args,
            succeeded: succeeded,
            statusSummary: summary,
            finishedAt: finishedAt,
            durationSeconds: duration
        )
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records.removeLast(records.count - maxRecords)
        }
        save()
    }

    func clear() {
        records.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> [OperationRecord] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([OperationRecord].self, from: data) else {
            return []
        }
        return decoded
    }
}
