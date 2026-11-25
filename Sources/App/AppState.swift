import Foundation
import Observation
import SwiftUI
import UserNotifications

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case installed
    case outdated
    case discover
    case services
    case taps
    case maintenance
    case brewfile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installed: "Installed"
        case .outdated: "Outdated"
        case .discover: "Discover"
        case .services: "Services"
        case .taps: "Taps"
        case .maintenance: "Maintenance"
        case .brewfile: "Brewfile"
        }
    }

    var systemImage: String {
        switch self {
        case .installed: "shippingbox"
        case .outdated: "arrow.triangle.2.circlepath"
        case .discover: "sparkle.magnifyingglass"
        case .services: "gearshape.2"
        case .taps: "spigot"
        case .maintenance: "stethoscope"
        case .brewfile: "doc.text"
        }
    }
}

enum InstalledFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case leaves = "Leaves"
    case formulae = "Formulae"
    case casks = "Casks"
    var id: String { rawValue }
}

@MainActor
@Observable
final class AppState {
    // Navigation & overlays
    var selectedSection: SidebarSection = .installed
    var selectedPackageID: String?
    var inspectorPresented: Bool = true
    var commandPalettePresented: Bool = false
    var logSheetPresented: Bool = false
    var searchText: String = ""
    var installedFilter: InstalledFilter = .all

    // Core data
    private(set) var installedPackages: [BrewPackage] = []
    private(set) var outdatedPackages: [OutdatedPackage] = []
    private(set) var services: [BrewServiceInfo] = []
    private(set) var taps: [BrewTapInfo] = []
    private(set) var brewVersion: String = "—"
    private(set) var cacheSizeBytes: Int64 = 0
    private(set) var catalogCount: Int = 0
    private(set) var isRefreshing: Bool = false
    private(set) var isSyncingCatalog: Bool = false
    private(set) var lastCheckedAt: Date?
    private(set) var lastError: String?

    // Settings
    var checkIntervalHours: Int = 6 {
        didSet { restartBackgroundTimer() }
    }
    var notifyOnOutdated: Bool = true

    // Dependencies
    let runner: BrewExecutable
    let queue: MutationQueue
    let catalog: CatalogStore?

    private var refreshTask: Task<Void, Never>?
    private var backgroundTimerTask: Task<Void, Never>?

    init(runner: BrewExecutable = LiveBrewRunner()) {
        self.runner = runner
        self.queue = MutationQueue(runner: runner)
        self.catalog = try? CatalogStore(inMemory: false)
        self.queue.setOnDrain { [weak self] in
            await self?.refreshAll()
        }

        // Stage 1: Instant local SQLite catalog count
        if let catalog {
            self.catalogCount = (try? catalog.count()) ?? 0
        }
        restartBackgroundTimer()
    }

    var prefixPath: String { runner.prefixPath }

    var outdatedIDs: Set<String> {
        Set(outdatedPackages.map(\.id))
    }

    var installedIDs: Set<String> {
        Set(installedPackages.map(\.id))
    }

    var selectedPackage: BrewPackage? {
        guard let selectedPackageID else { return nil }
        return installedPackages.first { $0.id == selectedPackageID }
    }

    var filteredInstalledPackages: [BrewPackage] {
        installedPackages.filter { pkg in
            switch installedFilter {
            case .all: true
            case .leaves: pkg.installedOnRequest
            case .formulae: pkg.kind == .formula
            case .casks: pkg.kind == .cask
            }
        }.filter { pkg in
            guard !searchText.isEmpty else { return true }
            return pkg.name.localizedCaseInsensitiveContains(searchText)
                || pkg.description.localizedCaseInsensitiveContains(searchText)
                || pkg.tap.localizedCaseInsensitiveContains(searchText)
        }
    }

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSizeBytes, countStyle: .file)
    }

    func startInitialLoad() {
        Task {
            await refreshAll()
            if catalogCount == 0 {
                await syncCatalog()
            }
        }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil

        let runner = self.runner
        async let infoRes = runner.run(args: ["info", "--json=v2", "--installed"])
        async let outRes = runner.run(args: ["outdated", "--json=v2"])
        async let srvRes = runner.run(args: ["services", "list", "--json"])
        async let tapRes = runner.run(args: ["tap-info", "--installed", "--json"])
        async let verRes = runner.run(args: ["--version"])
        async let cacheBytes = computeCacheSize()

        do {
            let (info, out, srv, tap, ver, bytes) = try await (infoRes, outRes, srvRes, tapRes, verRes, cacheBytes)
            if info.exitCode == 0 {
                self.installedPackages = try BrewOutputParser.parseInstalledInfo(info.stdout)
                if selectedPackageID == nil {
                    selectedPackageID = installedPackages.first?.id
                }
            }
            if out.exitCode == 0 {
                let parsedOutdated = try BrewOutputParser.parseOutdated(out.stdout)
                let prevCount = self.outdatedPackages.count
                self.outdatedPackages = parsedOutdated
                if notifyOnOutdated, parsedOutdated.count > prevCount, prevCount > 0 {
                    sendOutdatedNotification(count: parsedOutdated.count)
                }
            }
            if srv.exitCode == 0 {
                self.services = try BrewOutputParser.parseServices(srv.stdout)
            }
            if tap.exitCode == 0 {
                self.taps = try BrewOutputParser.parseTaps(tap.stdout)
            }
            if ver.exitCode == 0 {
                let firstLine = ver.stdout.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Homebrew"
                self.brewVersion = firstLine.replacingOccurrences(of: "Homebrew ", with: "")
            }
            self.cacheSizeBytes = bytes
            self.lastCheckedAt = Date()
        } catch {
            self.lastError = error.localizedDescription
        }

        isRefreshing = false
    }

    func syncCatalog() async {
        guard let catalog, !isSyncingCatalog else { return }
        isSyncingCatalog = true
        do {
            let count = try await catalog.syncCatalog()
            self.catalogCount = count
        } catch {
            self.lastError = "Catalog sync failed: \(error.localizedDescription)"
        }
        isSyncingCatalog = false
    }

    // MARK: - Mutations (FIFO Queue)

    func installPackage(name: String, kind: PackageKind) {
        let args = kind == .cask ? ["install", "--cask", name] : ["install", name]
        queue.enqueue(title: "Install \(name)", args: args)
    }

    func upgradePackage(name: String, kind: PackageKind) {
        let args = kind == .cask ? ["upgrade", "--cask", name] : ["upgrade", name]
        queue.enqueue(title: "Upgrade \(name)", args: args)
    }

    func upgradeAll() {
        guard !outdatedPackages.isEmpty else { return }
        queue.enqueue(title: "Upgrade All (\(outdatedPackages.count))", args: ["upgrade"])
        logSheetPresented = true
    }

    func uninstallPackage(_ pkg: BrewPackage) {
        let args = pkg.kind == .cask ? ["uninstall", "--cask", pkg.name] : ["uninstall", pkg.name]
        queue.enqueue(title: "Uninstall \(pkg.name)", args: args)
    }

    func togglePin(_ pkg: BrewPackage) {
        guard pkg.kind == .formula else { return }
        let cmd = pkg.pinned ? "unpin" : "pin"
        queue.enqueue(title: "\(pkg.pinned ? "Unpin" : "Pin") \(pkg.name)", args: [cmd, pkg.name])
    }

    func serviceAction(_ service: BrewServiceInfo, action: String) {
        queue.enqueue(title: "Service \(action) \(service.name)", args: ["services", action, service.name])
    }

    func addTap(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queue.enqueue(title: "Tap \(trimmed)", args: ["tap", trimmed])
    }

    func removeTap(_ name: String) {
        queue.enqueue(title: "Untap \(name)", args: ["untap", name])
    }

    func runDoctor() {
        queue.enqueue(title: "brew doctor", args: ["doctor"])
        logSheetPresented = true
    }

    func cleanCache() {
        queue.enqueue(title: "brew cleanup --prune=all", args: ["cleanup", "--prune=all"])
        logSheetPresented = true
    }

    func autoremove() {
        queue.enqueue(title: "brew autoremove", args: ["autoremove"])
        logSheetPresented = true
    }

    func generateBrewfileText() -> String {
        var lines: [String] = ["# Generated by Taproom"]
        for tap in taps where !tap.official {
            lines.append("tap \"\(tap.name)\"")
        }
        lines.append("")
        for pkg in installedPackages where pkg.kind == .formula && pkg.installedOnRequest {
            lines.append("brew \"\(pkg.fullName)\"")
        }
        lines.append("")
        for pkg in installedPackages where pkg.kind == .cask {
            lines.append("cask \"\(pkg.name)\"")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func importBrewfile(at url: URL) {
        queue.enqueue(title: "Brewfile bundle", args: ["bundle", "--file=\(url.path)"])
        logSheetPresented = true
    }

    // MARK: - Helpers

    private func computeCacheSize() async -> Int64 {
        await Task.detached(priority: .utility) {
            Self.directorySizeSync()
        }.value
    }

    nonisolated private static func directorySizeSync() -> Int64 {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }
        let brewCache = caches.appendingPathComponent("Homebrew", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: brewCache,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               vals.isRegularFile == true,
               let size = vals.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func restartBackgroundTimer() {
        backgroundTimerTask?.cancel()
        let hours = max(1, checkIntervalHours)
        backgroundTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(hours * 3600))
                guard !Task.isCancelled else { break }
                if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                    await self?.refreshAll()
                }
            }
        }
    }

    private func sendOutdatedNotification(count: Int) {
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "Homebrew Updates Available"
            content.body = "\(count) package\(count == 1 ? "" : "s") ready to upgrade in Taproom."
            let req = UNNotificationRequest(identifier: "taproom.outdated", content: content, trigger: nil)
            try? await center.add(req)
        }
    }
}
