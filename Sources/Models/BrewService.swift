import Foundation

enum ServiceStatus: String, Sendable, Hashable {
    case started
    case stopped
    case error
    case none
    case unknown

    init(rawStatus: String) {
        switch rawStatus.lowercased() {
        case "started": self = .started
        case "stopped", "none": self = .stopped
        case "error": self = .error
        default: self = .unknown
        }
    }

    var isRunning: Bool { self == .started }

    var displayLabel: String {
        switch self {
        case .started: "Running"
        case .stopped, .none: "Stopped"
        case .error: "Error"
        case .unknown: "Unknown"
        }
    }
}

struct BrewServiceInfo: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let exitCode: Int?
}
