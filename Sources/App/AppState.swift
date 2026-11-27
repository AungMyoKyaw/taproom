import Foundation
import Observation
import SwiftUI
import UserNotifications

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case installed
    case outdated
    case discover
    case adopt
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
        case .adopt: "Adopt Apps"
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
        case .adopt: "square.and.arrow.down.on.square"
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
    private(set) var discoveredApps: [DiscoveredApp] = []
    private(set) var operationHistory: [OperationRecord] = []
    private(set) var brewVersion: String = "—"
    private(set) var cacheSizeBytes: Int64 = 0
    private(set) var catalogCount: Int = 0
    private(set) var isRefreshing: Bool = false
    private(set) var isSyncingCatalog: Bool = false
    private(set) var isScanningApps: Bool = false
    private(set) var lastCheckedAt: Date?
    private(set) var lastError: String?

    // Settings (persisted in UserDefaults)
    private enum DefaultsKey {
        static let checkIntervalHours = "taproom.checkIntervalHours"
        static let notifyOnOutdated = "taproom.notifyOnOutdated"
        static let includeGreedyCasks = "taproom.includeGreedyCasks"
        static let customBrewPath = "taproom.customBrewPath"
        static let httpProxy = "taproom.httpProxy"
    }

    var checkIntervalHours: Int = 6 {
        didSet {
            userDefaults.set(checkIntervalHours, forKey: DefaultsKey.checkIntervalHours)
            restartBackgroundTimer()
        }
    }
    var notifyOnOutdated: Bool = true {
        didSet {
            userDefaults.set(notifyOnOutdated, forKey: DefaultsKey.notifyOnOutdated)
        }
    }
    var includeGreedyCasks: Bool = false {
        didSet {
            userDefaults.set(includeGreedyCasks, forKey: DefaultsKey.includeGreedyCasks)
        }
    }
    var customBrewPath: String = "" {
        didSet {
            userDefaults.set(customBrewPath, forKey: DefaultsKey.customBrewPath)
        }
    }
    var httpProxy: String = "" {
        didSet {
            userDefaults.set(httpProxy, forKey: DefaultsKey.httpProxy)
        }
    }

    // Dependencies
    let runner: BrewExecutable
    let queue: MutationQueue
    let catalog: CatalogStore?
    private let historyStore: OperationHistoryStore
    private let userDefaults: UserDefaults

    private var pendingRefresh: Bool = false
    private var diskSizeTask: Task<Void, Never>?
    private var backgroundTimerTask: Task<Void, Never>?

    init(
        runner: BrewExecutable = LiveBrewRunner(),
        userDefaults: UserDefaults = .standard,
        catalog: CatalogStore? = nil
    ) {
        self.runner = runner
        self.userDefaults = userDefaults
        self.historyStore = OperationHistoryStore(userDefaults: userDefaults)
        self.operationHistory = historyStore.records
        self.queue = MutationQueue(runner: runner)
        self.catalog = catalog ?? (try? CatalogStore(inMemory: false))

        if userDefaults.object(forKey: DefaultsKey.checkIntervalHours) != nil {
            self.checkIntervalHours = max(1, userDefaults.integer(forKey: DefaultsKey.checkIntervalHours))
        }
        if userDefaults.object(forKey: DefaultsKey.notifyOnOutdated) != nil {
            self.notifyOnOutdated = userDefaults.bool(forKey: DefaultsKey.notifyOnOutdated)
        }
        if userDefaults.object(forKey: DefaultsKey.includeGreedyCasks) != nil {
            self.includeGreedyCasks = userDefaults.bool(forKey: DefaultsKey.includeGreedyCasks)
        }
        if let savedBrewPath = userDefaults.string(forKey: DefaultsKey.customBrewPath) {
            self.customBrewPath = savedBrewPath
        }
        if let savedProxy = userDefaults.string(forKey: DefaultsKey.httpProxy) {
            self.httpProxy = savedProxy
        }

        self.queue.setOnJobFinish { [weak self] job in
            guard let self else { return }
            self.historyStore.append(job: job)
            self.operationHistory = self.historyStore.records
        }
        self.queue.setOnDrain { [weak self] in
            await self?.refreshAll()
        }

        // Stage 1: Instant local SQLite catalog count
        if let catalog = self.catalog {
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

    var adoptableAppCount: Int {
        discoveredApps.filter(\.isAdoptable).count
    }

    var rosettaAppCount: Int {
        discoveredApps.filter(\.isRosetta).count
    }

    func dismissError() {
        lastError = nil
    }

    func scanLocalApplications(directories: [URL] = AppScanner.defaultDirectories()) async {
        guard !isScanningApps else { return }
        isScanningApps = true
        let installedCasks = Set(installedPackages.filter { $0.kind == .cask }.map(\.name))
        let lookup = (try? catalog?.caskTokenLookup()) ?? [:]
        let scanned = await Task.detached(priority: .utility) {
            AppScanner.scan(directories: directories, installedCaskNames: installedCasks, caskLookup: lookup)
        }.value
        self.discoveredApps = scanned
        isScanningApps = false
    }

    func adoptApp(_ app: DiscoveredApp) {
        guard let token = app.matchedCaskToken else { return }
        queue.enqueue(title: "Adopt \(app.name) (\(token))", args: ["install", "--cask", "--adopt", token])
    }

    func clearOperationHistory() {
        historyStore.clear()
        operationHistory = []
    }

    func dependents(of formulaName: String) -> [BrewPackage] {
        installedPackages.filter { $0.dependencies.contains(formulaName) }
    }

    func selectPackage(named name: String) {
        if let match = installedPackages.first(where: { $0.name == name || $0.fullName == name }) {
            selectedSection = .installed
            selectedPackageID = match.id
            inspectorPresented = true
        }
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
        if isRefreshing {
            pendingRefresh = true
            return
        }
        isRefreshing = true
        pendingRefresh = false
        lastError = nil

        let runner = self.runner
        let outdatedArgs = includeGreedyCasks ? ["outdated", "--json=v2", "--greedy"] : ["outdated", "--json=v2"]
        async let infoRes = runner.run(args: ["info", "--json=v2", "--installed"])
        async let outRes = runner.run(args: outdatedArgs)
        async let srvRes = runner.run(args: ["services", "list", "--json"])
        async let tapRes = runner.run(args: ["tap-info", "--installed", "--json"])
        async let verRes = runner.run(args: ["--version"])
        async let cacheBytes = computeCacheSize()

        do {
            let (info, out, srv, tap, ver, bytes) = try await (infoRes, outRes, srvRes, tapRes, verRes, cacheBytes)
            var failures: [String] = []

            if info.exitCode == 0 {
                let parsed = try BrewOutputParser.parseInstalledInfo(info.stdout)
                self.installedPackages = parsed
                if selectedPackageID == nil {
                    selectedPackageID = parsed.first?.id
                }
                scheduleDiskSizeComputation(for: parsed)
            } else {
                failures.append(Self.formatCommandFailure("brew info", output: info))
            }

            if out.exitCode == 0 {
                let parsedOutdated = try BrewOutputParser.parseOutdated(out.stdout)
                let prevCount = self.outdatedPackages.count
                self.outdatedPackages = parsedOutdated
                if notifyOnOutdated, parsedOutdated.count > prevCount, prevCount > 0 {
                    sendOutdatedNotification(count: parsedOutdated.count)
                }
            } else {
                failures.append(Self.formatCommandFailure("brew outdated", output: out))
            }

            if srv.exitCode == 0 {
                self.services = try BrewOutputParser.parseServices(srv.stdout)
            } else {
                failures.append(Self.formatCommandFailure("brew services", output: srv))
            }

            if tap.exitCode == 0 {
                self.taps = try BrewOutputParser.parseTaps(tap.stdout)
            } else {
                failures.append(Self.formatCommandFailure("brew tap-info", output: tap))
            }

            if ver.exitCode == 0 {
                let firstLine = ver.stdout.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Homebrew"
                self.brewVersion = firstLine.replacingOccurrences(of: "Homebrew ", with: "")
            } else {
                failures.append(Self.formatCommandFailure("brew --version", output: ver))
            }

            self.cacheSizeBytes = bytes
            self.lastCheckedAt = Date()
            if !failures.isEmpty {
                self.lastError = failures.joined(separator: " · ")
            }
        } catch {
            self.lastError = error.localizedDescription
        }

        isRefreshing = false
        if pendingRefresh {
            pendingRefresh = false
            await refreshAll()
        }
    }

    private static func formatCommandFailure(_ command: String, output: BrewCommandOutput) -> String {
        let detail = output.stderr
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if detail.isEmpty {
            return "\(command) failed (exit \(output.exitCode))"
        }
        return "\(command): \(detail)"
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
        let args = includeGreedyCasks ? ["upgrade", "--greedy"] : ["upgrade"]
        queue.enqueue(title: "Upgrade All (\(outdatedPackages.count))", args: args)
        logSheetPresented = true
    }

    func uninstallPackage(_ pkg: BrewPackage, zap: Bool = false) {
        let args: [String]
        if pkg.kind == .cask {
            args = zap ? ["uninstall", "--cask", "--zap", pkg.name] : ["uninstall", "--cask", pkg.name]
        } else {
            args = ["uninstall", pkg.name]
        }
        let title = (pkg.kind == .cask && zap) ? "Zap \(pkg.name)" : "Uninstall \(pkg.name)"
        queue.enqueue(title: title, args: args)
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

    func runMissingCheck() {
        queue.enqueue(title: "brew missing", args: ["missing"])
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

    private func scheduleDiskSizeComputation(for packages: [BrewPackage]) {
        diskSizeTask?.cancel()
        let prefix = self.prefixPath
        let targets: [(id: String, path: String)] = packages.map { pkg in
            let sub = pkg.kind == .formula ? "Cellar" : "Caskroom"
            let path = "\(prefix)/\(sub)/\(pkg.name)/\(pkg.version)"
            return (pkg.id, path)
        }

        diskSizeTask = Task.detached(priority: .utility) { [weak self] in
            var computed: [String: (path: String, size: Int64)] = [:]
            for item in targets {
                if Task.isCancelled { return }
                let url = URL(fileURLWithPath: item.path, isDirectory: true)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }
                let size = Self.directorySizeSync(at: url)
                computed[item.id] = (item.path, size)
            }
            guard !Task.isCancelled, !computed.isEmpty else { return }
            let results = computed
            let taskCancelled = Task.isCancelled
            guard !taskCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                for idx in self.installedPackages.indices {
                    let id = self.installedPackages[idx].id
                    if let match = results[id] {
                        self.installedPackages[idx].installedPath = match.path
                        self.installedPackages[idx].diskSizeBytes = match.size
                    }
                }
            }
        }
    }

    private func computeCacheSize() async -> Int64 {
        await Task.detached(priority: .utility) {
            guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return 0
            }
            let brewCache = caches.appendingPathComponent("Homebrew", isDirectory: true)
            return Self.directorySizeSync(at: brewCache)
        }.value
    }

    nonisolated private static func directorySizeSync(at root: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
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
