import Foundation

enum MutationJobState: Hashable, Sendable {
    case queued
    case running
    case succeeded
    case failed(String)
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .queued, .running: false
        case .succeeded, .failed, .cancelled: true
        }
    }

    var label: String {
        switch self {
        case .queued: "Queued"
        case .running: "Running"
        case .succeeded: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}

struct MutationJob: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let args: [String]
    var state: MutationJobState
    let createdAt: Date
    var startedAt: Date?
    var finishedAt: Date?
    var logLines: [String]

    init(id: UUID = UUID(), title: String, args: [String]) {
        self.id = id
        self.title = title
        self.args = args
        self.state = .queued
        self.createdAt = Date()
        self.logLines = []
    }
}
