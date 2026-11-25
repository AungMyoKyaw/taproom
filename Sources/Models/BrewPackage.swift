import Foundation

enum PackageKind: String, Codable, Sendable, CaseIterable, Hashable {
    case formula
    case cask

    var badgeTitle: String {
        switch self {
        case .formula: "FORMULA"
        case .cask: "CASK"
        }
    }
}

struct BrewPackage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fullName: String
    let kind: PackageKind
    let version: String
    let tap: String
    let description: String
    let homepage: String
    let license: String?
    let installedOnRequest: Bool
    let pinned: Bool
    let dependencies: [String]
    let caveats: String?
    let installedPath: String?
    let diskSizeBytes: Int64?

    var formattedSize: String {
        guard let diskSizeBytes, diskSizeBytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: diskSizeBytes, countStyle: .file)
    }
}

struct OutdatedPackage: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: PackageKind
    let installedVersion: String
    let availableVersion: String
    let pinned: Bool
}

struct CatalogEntry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fullName: String
    let kind: PackageKind
    let version: String
    let tap: String
    let description: String
    let homepage: String
}
