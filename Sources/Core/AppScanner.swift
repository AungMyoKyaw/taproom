import Foundation

enum AppArchitecture: String, Sendable, Hashable {
    case arm64 = "ARM64"
    case universal = "Universal"
    case x86_64 = "Rosetta"
    case unknown = "Unknown"
}

struct DiscoveredApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let version: String
    let path: String
    let architecture: AppArchitecture
    let matchedCaskToken: String?
    let isManagedByBrew: Bool

    var isAdoptable: Bool {
        !isManagedByBrew && matchedCaskToken != nil
    }

    var isRosetta: Bool {
        architecture == .x86_64
    }
}

enum AppScanner {
    static func defaultDirectories() -> [URL] {
        let systemApps = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        return [systemApps, userApps]
    }

    static func scan(
        directories: [URL] = defaultDirectories(),
        installedCaskNames: Set<String>,
        caskLookup: [String: String]
    ) -> [DiscoveredApp] {
        let fm = FileManager.default
        let normalizedInstalled: [String: String] = Dictionary(
            installedCaskNames.map { (CatalogStore.normalizeToken($0), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var seenPaths = Set<String>()
        var results: [DiscoveredApp] = []

        for dir in directories {
            guard let items = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in items where url.pathExtension.lowercased() == "app" {
                let path = url.path
                guard seenPaths.insert(path).inserted else { continue }

                let plistURL = url.appendingPathComponent("Contents/Info.plist")
                let plist = (try? Data(contentsOf: plistURL)).flatMap {
                    try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
                } ?? [:]

                let bundleID = plist["CFBundleIdentifier"] as? String
                if let bundleID, bundleID.hasPrefix("com.apple.") {
                    continue
                }

                let fallbackName = url.deletingPathExtension().lastPathComponent
                let displayName = (plist["CFBundleDisplayName"] as? String)
                    ?? (plist["CFBundleName"] as? String)
                    ?? fallbackName
                let version = (plist["CFBundleShortVersionString"] as? String)
                    ?? (plist["CFBundleVersion"] as? String)
                    ?? "—"

                let execName = plist["CFBundleExecutable"] as? String
                let arch = execName.map {
                    detectArchitecture(executableURL: url.appendingPathComponent("Contents/MacOS/\($0)"))
                } ?? .unknown

                let resolvedPath = url.resolvingSymlinksInPath().path
                let isCaskroomLink = resolvedPath.contains("/Caskroom/")

                let candidates = [
                    CatalogStore.normalizeToken(fallbackName),
                    CatalogStore.normalizeToken(displayName)
                ]
                var matchedToken: String?
                var isManaged = isCaskroomLink

                for key in candidates where !key.isEmpty {
                    if let installed = normalizedInstalled[key] {
                        matchedToken = installed
                        isManaged = true
                        break
                    }
                    if let catalogMatch = caskLookup[key] {
                        matchedToken = catalogMatch
                        break
                    }
                }

                results.append(DiscoveredApp(
                    id: path,
                    name: displayName,
                    bundleIdentifier: bundleID,
                    version: version,
                    path: path,
                    architecture: arch,
                    matchedCaskToken: matchedToken,
                    isManagedByBrew: isManaged
                ))
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.isAdoptable != rhs.isAdoptable { return lhs.isAdoptable && !rhs.isAdoptable }
            if lhs.isRosetta != rhs.isRosetta { return lhs.isRosetta && !rhs.isRosetta }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func detectArchitecture(executableURL: URL) -> AppArchitecture {
        guard let handle = try? FileHandle(forReadingFrom: executableURL) else { return .unknown }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 4096), header.count >= 8 else { return .unknown }

        let magic = readUInt32BE(header, offset: 0)
        // Fat / Universal binary (0xCAFEBABE or 0xBEBAFECA)
        if magic == 0xCAFE_BABE || magic == 0xBEBA_FECA {
            let isBigEndian = (magic == 0xCAFE_BABE)
            let rawCount = isBigEndian ? readUInt32BE(header, offset: 4) : readUInt32LE(header, offset: 4)
            let archCount = min(Int(rawCount), 16)
            var hasArm64 = false
            var hasX86_64 = false
            for i in 0..<archCount {
                let offset = 8 + i * 20
                guard offset + 4 <= header.count else { break }
                let cpuType = isBigEndian ? readUInt32BE(header, offset: offset) : readUInt32LE(header, offset: offset)
                if cpuType == 0x0100_000C { hasArm64 = true }
                if cpuType == 0x0100_0007 { hasX86_64 = true }
            }
            if hasArm64 && hasX86_64 { return .universal }
            if hasArm64 { return .arm64 }
            if hasX86_64 { return .x86_64 }
            return .unknown
        }

        // Thin 64-bit Mach-O
        if magic == 0xFEED_FACF {
            return mapCPUType(readUInt32BE(header, offset: 4))
        }
        if magic == 0xCFFA_EDFE {
            return mapCPUType(readUInt32LE(header, offset: 4))
        }
        return .unknown
    }

    private static func mapCPUType(_ cpuType: UInt32) -> AppArchitecture {
        switch cpuType {
        case 0x0100_000C: .arm64
        case 0x0100_0007: .x86_64
        default: .unknown
        }
    }

    private static func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
