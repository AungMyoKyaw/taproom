import SwiftUI

struct MaintenanceView: View {
    @Environment(AppState.self) private var appState
    @State private var confirmAction: PendingMaintenance?

    private enum PendingMaintenance: Identifiable {
        case cleanCache
        case autoremove
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("MAINTENANCE & DIAGNOSTICS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    MaintenanceCard(
                        title: "Homebrew Doctor",
                        badge: "Diagnostics",
                        badgeColor: TaproomTheme.statusCurrent,
                        description: "Checks Cellar symlinks, PATH order, and broken dylibs.",
                        buttonTitle: "Run brew doctor",
                        isPrimary: true
                    ) {
                        appState.runDoctor()
                    }

                    MaintenanceCard(
                        title: "Cache & Old Downloads",
                        badge: "\(appState.formattedCacheSize) cached",
                        badgeColor: TaproomTheme.statusOutdated,
                        description: "Prune old bottle tarballs and cask installers from ~/Library/Caches/Homebrew.",
                        buttonTitle: "Clean Cache",
                        isPrimary: false
                    ) {
                        confirmAction = .cleanCache
                    }

                    MaintenanceCard(
                        title: "Brewfile Snapshot",
                        badge: "\(appState.installedPackages.filter(\.installedOnRequest).count) leaves",
                        badgeColor: TaproomTheme.statusCurrent,
                        description: "Inspect, export, or restore your Homebrew environment from a Brewfile.",
                        buttonTitle: "Open Brewfile",
                        isPrimary: false
                    ) {
                        appState.selectedSection = .brewfile
                    }

                    MaintenanceCard(
                        title: "Orphaned Dependencies",
                        badge: "Autoremove",
                        badgeColor: TaproomTheme.statusOutdated,
                        description: "Remove formula dependencies no longer required by any installed leaf package.",
                        buttonTitle: "Run Autoremove",
                        isPrimary: false
                    ) {
                        confirmAction = .autoremove
                    }

                    MaintenanceCard(
                        title: "Missing Dependencies",
                        badge: "Verify",
                        badgeColor: TaproomTheme.statusCurrent,
                        description: "Check installed formulae for missing runtime dependencies via brew missing.",
                        buttonTitle: "Check Missing",
                        isPrimary: false
                    ) {
                        appState.runMissingCheck()
                    }
                }

                historySection
            }
            .padding(20)
        }
        .background(TaproomTheme.surface)
        .confirmationDialog(
            confirmAction == .cleanCache ? "Clean Homebrew Cache?" : "Run brew autoremove?",
            isPresented: Binding(
                get: { confirmAction != nil },
                set: { if !$0 { confirmAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if confirmAction == .cleanCache {
                Button("Clean Cache (\(appState.formattedCacheSize))", role: .destructive) {
                    appState.cleanCache()
                    confirmAction = nil
                }
            } else if confirmAction == .autoremove {
                Button("Run Autoremove", role: .destructive) {
                    appState.autoremove()
                    confirmAction = nil
                }
            }
            Button("Cancel", role: .cancel) { confirmAction = nil }
        } message: {
            Text(
                confirmAction == .cleanCache
                    ? "Runs brew cleanup --prune=all to delete cached downloads and old formula versions."
                    : "Uninstalls formula dependencies no longer required by any requested leaf package."
            )
        }
    }
}

private struct MaintenanceCard: View {
    let title: String
    let badge: String
    let badgeColor: Color
    let description: String
    let buttonTitle: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(badge)
                    .font(TaproomTheme.mono(11, weight: .medium))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.14), in: Capsule())
            }
            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if isPrimary {
                Button(buttonTitle, action: action)
                    .buttonStyle(TaproomPrimaryButtonStyle())
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .taproomCard(cornerRadius: TaproomTheme.Radius.md, padding: 20)
    }
}

private extension MaintenanceView {
    var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("OPERATION HISTORY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !appState.operationHistory.isEmpty {
                    Button("Clear History") {
                        appState.clearOperationHistory()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            if appState.operationHistory.isEmpty {
                Text("No completed Homebrew operations recorded yet.")
                    .font(TaproomTheme.monoSm)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .taproomCard(cornerRadius: TaproomTheme.Radius.md, padding: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.operationHistory.prefix(20)) { record in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(record.succeeded ? TaproomTheme.statusCurrent : TaproomTheme.statusError)
                                .frame(width: 7, height: 7)
                            Text(record.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text(record.statusSummary)
                                .font(TaproomTheme.mono(11))
                                .foregroundStyle(record.succeeded ? .secondary : TaproomTheme.statusError)
                            Text(String(format: "%.1fs", record.durationSeconds))
                                .font(TaproomTheme.mono(10))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                            Text(record.finishedAt.formatted(.relative(presentation: .named)))
                                .font(TaproomTheme.mono(10))
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                .taproomCard(cornerRadius: TaproomTheme.Radius.md, padding: 0)
            }
        }
    }
}
