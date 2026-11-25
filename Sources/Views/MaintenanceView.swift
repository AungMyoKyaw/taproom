import SwiftUI

struct MaintenanceView: View {
    @Environment(AppState.self) private var appState

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
                        appState.cleanCache()
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
                        appState.autoremove()
                    }
                }
            }
            .padding(20)
        }
        .background(TaproomTheme.surface)
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
                    .buttonStyle(.borderedProminent)
                    .tint(TaproomTheme.accent)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TaproomTheme.border, lineWidth: 1)
        )
    }
}
