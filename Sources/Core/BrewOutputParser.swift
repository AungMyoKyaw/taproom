import Foundation

enum BrewParserError: Error, LocalizedError {
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let context): "Invalid JSON payload: \(context)"
        }
    }
}

struct BrewfileContents: Equatable, Sendable {
    var taps: [String]
    var formulae: [String]
    var casks: [String]
}

enum BrewOutputParser {
    /// Strips leading non-JSON warning lines emitted by `brew` before `{` or `[`.
    static func extractJSONPayload(from raw: String) -> Data? {
        guard let startIndex = raw.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            return nil
        }
        return Data(raw[startIndex...].utf8)
    }

    static func parseInstalledInfo(_ raw: String) throws -> [BrewPackage] {
        guard let data = extractJSONPayload(from: raw) else {
            throw BrewParserError.invalidJSON("brew info --json=v2 --installed")
        }
        let decoded = try JSONDecoder().decode(InfoV2Response.self, from: data)
        var packages: [BrewPackage] = []
        packages.reserveCapacity(decoded.formulae.count + decoded.casks.count)

        for f in decoded.formulae {
            let latestInstalled = f.installed.last
            let version = latestInstalled?.version ?? f.versions.stable ?? "unknown"
            let onRequest = latestInstalled?.installedOnRequest ?? true
            packages.append(
                BrewPackage(
                    id: "formula:\(f.name)",
                    name: f.name,
                    fullName: f.fullName,
                    kind: .formula,
                    version: version,
                    tap: f.tap,
                    description: f.desc ?? "",
                    homepage: f.homepage ?? "",
                    license: f.license,
                    installedOnRequest: onRequest,
                    pinned: f.pinned,
                    dependencies: f.dependencies,
                    caveats: f.caveats,
                    installedPath: nil,
                    diskSizeBytes: nil
                )
            )
        }

        for c in decoded.casks {
            packages.append(
                BrewPackage(
                    id: "cask:\(c.token)",
                    name: c.token,
                    fullName: c.fullToken,
                    kind: .cask,
                    version: c.installed ?? c.version,
                    tap: c.tap,
                    description: c.desc ?? c.name.first ?? "",
                    homepage: c.homepage ?? "",
                    license: nil,
                    installedOnRequest: true,
                    pinned: false,
                    dependencies: [],
                    caveats: c.caveats,
                    installedPath: nil,
                    diskSizeBytes: nil
                )
            )
        }

        return packages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func parseOutdated(_ raw: String) throws -> [OutdatedPackage] {
        guard let data = extractJSONPayload(from: raw) else {
            throw BrewParserError.invalidJSON("brew outdated --json=v2")
        }
        let decoded = try JSONDecoder().decode(OutdatedV2Response.self, from: data)
        var items: [OutdatedPackage] = []

        for f in decoded.formulae {
            items.append(
                OutdatedPackage(
                    id: "formula:\(f.name)",
                    name: f.name,
                    kind: .formula,
                    installedVersion: f.installedVersions.last ?? "?",
                    availableVersion: f.currentVersion,
                    pinned: f.pinned
                )
            )
        }
        for c in decoded.casks {
            items.append(
                OutdatedPackage(
                    id: "cask:\(c.name)",
                    name: c.name,
                    kind: .cask,
                    installedVersion: c.installedVersions.last ?? "?",
                    availableVersion: c.currentVersion,
                    pinned: false
                )
            )
        }
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func parseServices(_ raw: String) throws -> [BrewServiceInfo] {
        guard let data = extractJSONPayload(from: raw) else {
            throw BrewParserError.invalidJSON("brew services list --json")
        }
        let decoded = try JSONDecoder().decode([ServiceJSON].self, from: data)
        return decoded.map {
            BrewServiceInfo(
                name: $0.name,
                status: ServiceStatus(rawStatus: $0.status),
                user: $0.user,
                file: $0.file,
                exitCode: $0.exitCode
            )
        }
    }

    static func parseTaps(_ raw: String) throws -> [BrewTapInfo] {
        guard let data = extractJSONPayload(from: raw) else {
            throw BrewParserError.invalidJSON("brew tap-info --installed --json")
        }
        let decoded = try JSONDecoder().decode([TapJSON].self, from: data)
        return decoded.map {
            BrewTapInfo(
                name: $0.name,
                official: $0.official,
                path: $0.path,
                formulaCount: $0.formulaNames.count,
                caskCount: $0.caskTokens.count
            )
        }
    }

    static func parseBrewfile(_ text: String) -> BrewfileContents {
        var taps: [String] = []
        var formulae: [String] = []
        var casks: [String] = []

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if let value = extractQuotedArg(after: "tap ", in: line) {
                taps.append(value)
            } else if let value = extractQuotedArg(after: "brew ", in: line) {
                formulae.append(value)
            } else if let value = extractQuotedArg(after: "cask ", in: line) {
                casks.append(value)
            }
        }
        return BrewfileContents(taps: taps, formulae: formulae, casks: casks)
    }

    private static func extractQuotedArg(after prefix: String, in line: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let rest = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        for quote in ["\"", "'"] {
            if rest.hasPrefix(quote) {
                let afterOpen = rest.dropFirst()
                if let closeIdx = afterOpen.firstIndex(of: Character(quote)) {
                    return String(afterOpen[..<closeIdx])
                }
            }
        }
        return nil
    }
}

// MARK: - Private JSON DTOs

private struct InfoV2Response: Decodable {
    let formulae: [FormulaInfoJSON]
    let casks: [CaskInfoJSON]
}

private struct FormulaInfoJSON: Decodable {
    struct Versions: Decodable { let stable: String? }
    struct InstalledEntry: Decodable {
        let version: String
        let installedOnRequest: Bool?
        enum CodingKeys: String, CodingKey {
            case version
            case installedOnRequest = "installed_on_request"
        }
    }
    let name: String
    let fullName: String
    let tap: String
    let desc: String?
    let homepage: String?
    let license: String?
    let versions: Versions
    let installed: [InstalledEntry]
    let dependencies: [String]
    let caveats: String?
    let pinned: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap, desc, homepage, license, versions, installed, dependencies, caveats, pinned
    }
}

private struct CaskInfoJSON: Decodable {
    let token: String
    let fullToken: String
    let name: [String]
    let tap: String
    let desc: String?
    let homepage: String?
    let version: String
    let installed: String?
    let caveats: String?

    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name, tap, desc, homepage, version, installed, caveats
    }
}

private struct OutdatedV2Response: Decodable {
    struct FormulaOutdated: Decodable {
        let name: String
        let installedVersions: [String]
        let currentVersion: String
        let pinned: Bool
        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
            case pinned
        }
    }
    struct CaskOutdated: Decodable {
        let name: String
        let installedVersions: [String]
        let currentVersion: String
        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
        }
    }
    let formulae: [FormulaOutdated]
    let casks: [CaskOutdated]
}

private struct ServiceJSON: Decodable {
    let name: String
    let status: String
    let user: String?
    let file: String?
    let exitCode: Int?
    enum CodingKeys: String, CodingKey {
        case name, status, user, file
        case exitCode = "exit_code"
    }
}

private struct TapJSON: Decodable {
    let name: String
    let official: Bool
    let path: String?
    let formulaNames: [String]
    let caskTokens: [String]
    enum CodingKeys: String, CodingKey {
        case name, official, path
        case formulaNames = "formula_names"
        case caskTokens = "cask_tokens"
    }
}
