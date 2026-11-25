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
    var installedPath: String?
    var diskSizeBytes: Int64?

    var formattedSize: String {
        guard let diskSizeBytes, diskSizeBytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: diskSizeBytes, countStyle: .file)
    }

    var sortableSize: Int64 { diskSizeBytes ?? -1 }
    var sortableKind: String { kind.rawValue }
    var sortableStatus: String { pinned ? "pinned" : "current" }
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
    let kind: PackageKind
    let id: String
    let name: String
    let fullName: String
    let tap: String
    let version: String
    let homepage: String
    let description: String

    init(
        id: String,
        name: String,
        fullName: String,
        kind: PackageKind,
        version: String,
        tap: String,
        description: String,
        homepage: String
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.kind = kind
        self.version = version
        self.tap = tap
        self.description = description
        self.homepage = homepage
    }
}
