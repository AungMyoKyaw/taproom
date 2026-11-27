import SwiftUI

struct AdoptAppsView: View {
    @Environment(AppState.self) private var appState
    @State private var filterMode: AdoptFilter = .all

    private enum AdoptFilter: String, CaseIterable, Identifiable {
        case all = "All Apps"
        case adoptable = "Adoptable"
        case rosetta = "Rosetta (x86_64)"
        case managed = "Brew Managed"
        var id: String { rawValue }
    }

    private var filteredApps: [DiscoveredApp] {
        let query = appState.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.discoveredApps.filter { app in
            switch filterMode {
            case .all: true
            case .adoptable: app.isAdoptable
            case .rosetta: app.isRosetta
            case .managed: app.isManagedByBrew
            }
        }.filter { app in
            guard !query.isEmpty else { return true }
            return app.name.localizedCaseInsensitiveContains(query)
                || (app.matchedCaskToken?.localizedCaseInsensitiveContains(query) ?? false)
                || (app.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if appState.isScanningApps && appState.discoveredApps.isEmpty {
                ProgressView("Scanning /Applications & ~/Applications…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TaproomTheme.surface)
            } else if filteredApps.isEmpty {
                ContentUnavailableView(
                    "No Matching Applications",
                    systemImage: "app.dashed",
                    description: Text(appState.catalogCount == 0
                        ? "Sync the Discover catalog first so Taproom can match installed apps to Homebrew casks."
                        : "No applications matched the current filter.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TaproomTheme.surface)
            } else {
                Table(filteredApps) {
                    TableColumn("Application") { app in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 13, weight: .medium))
                            if let bundleID = app.bundleIdentifier {
                                Text(bundleID)
                                    .font(TaproomTheme.mono(10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .width(min: 190, ideal: 250)

                    TableColumn("Version") { app in
                        Text(app.version)
                            .font(TaproomTheme.monoMd)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 110)

                    TableColumn("Arch") { app in
                        ArchBadge(arch: app.architecture)
                    }
                    .width(96)

                    TableColumn("Cask Match") { app in
                        if let token = app.matchedCaskToken {
                            Text(token)
                                .font(TaproomTheme.monoSm)
                                .foregroundStyle(app.isManagedByBrew ? TaproomTheme.statusCurrent : TaproomTheme.accent)
                        } else {
                            Text("—")
                                .font(TaproomTheme.monoSm)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Action") { app in
                        if app.isManagedByBrew {
                            Text("Managed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TaproomTheme.statusCurrent)
                        } else if app.isAdoptable {
                            let isQueuedOrRunning = appState.queue.jobs.contains {
                                !$0.state.isTerminal && $0.args.contains("--adopt") && $0.args.contains(app.matchedCaskToken ?? "")
                            }
                            if isQueuedOrRunning {
                                Text("Adopting…")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TaproomTheme.accent)
                            } else {
                                Button("Adopt") {
                                    appState.adoptApp(app)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Text("Unmanaged")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(105)
                }
                .scrollContentBackground(.hidden)
                .background(TaproomTheme.surface)
            }
        }
        .background(TaproomTheme.surface)
        .task {
            if appState.discoveredApps.isEmpty {
                await appState.scanLocalApplications()
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            ForEach(AdoptFilter.allCases) { filter in
                let isSelected = filterMode == filter
                Button {
                    filterMode = filter
                } label: {
                    Text(filterTitle(filter))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ? TaproomTheme.accent.opacity(0.16) : TaproomTheme.surfaceElevated,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? TaproomTheme.accent : TaproomTheme.border, lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? TaproomTheme.accent : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                Task { await appState.scanLocalApplications() }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(appState.isScanningApps)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TaproomTheme.surface)
    }

    private func filterTitle(_ filter: AdoptFilter) -> String {
        switch filter {
        case .all: "All (\(appState.discoveredApps.count))"
        case .adoptable: "Adoptable (\(appState.adoptableAppCount))"
        case .rosetta: "Rosetta (\(appState.rosettaAppCount))"
        case .managed: "Managed (\(appState.discoveredApps.filter(\.isManagedByBrew).count))"
        }
    }
}

private struct ArchBadge: View {
    let arch: AppArchitecture

    var body: some View {
        let color: Color = switch arch {
        case .arm64, .universal: TaproomTheme.statusCurrent
        case .x86_64: TaproomTheme.statusOutdated
        case .unknown: .secondary
        }
        Text(arch.rawValue)
            .font(TaproomTheme.mono(10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }
}
