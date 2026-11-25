import SwiftUI

struct OutdatedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if appState.outdatedPackages.isEmpty {
                ContentUnavailableView(
                    "Everything Up to Date",
                    systemImage: "checkmark.seal.fill",
                    description: Text("All installed Homebrew formulae and casks are on their latest versions.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TaproomTheme.surface)
            } else {
                Table(appState.outdatedPackages) {
                    TableColumn("Package") { pkg in
                        Text(pkg.name)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .width(min: 180, ideal: 260)

                    TableColumn("Installed") { pkg in
                        Text(pkg.installedVersion)
                            .font(TaproomTheme.mono(12))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 110, ideal: 150)

                    TableColumn("Available") { pkg in
                        Text("→ \(pkg.availableVersion)")
                            .font(TaproomTheme.mono(12, weight: .semibold))
                            .foregroundStyle(TaproomTheme.statusOutdated)
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Kind") { pkg in
                        KindBadge(kind: pkg.kind)
                    }
                    .width(80)

                    TableColumn("Action") { pkg in
                        Button("Upgrade") {
                            appState.upgradePackage(name: pkg.name, kind: pkg.kind)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .width(96)
                }
                .scrollContentBackground(.hidden)
                .background(TaproomTheme.surface)
            }

            if let activeOrLast = appState.queue.activeJob ?? appState.queue.jobs.last {
                Divider()
                liveOutputPane(activeOrLast)
                    .frame(height: 280)
            }
        }
        .background(TaproomTheme.surface)
    }

    private var headerBar: some View {
        HStack {
            Text("\(appState.outdatedPackages.count) package\(appState.outdatedPackages.count == 1 ? "" : "s") with newer versions available.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Check Now") {
                Task { await appState.refreshAll() }
            }
            .buttonStyle(.bordered)
            .disabled(appState.isRefreshing)

            Button("Upgrade All (\(appState.outdatedPackages.count))") {
                appState.upgradeAll()
            }
            .buttonStyle(.borderedProminent)
            .tint(TaproomTheme.accent)
            .disabled(appState.outdatedPackages.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TaproomTheme.surface)
    }

    private func liveOutputPane(_ job: MutationJob) -> some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(job.state == .running ? TaproomTheme.accent : TaproomTheme.statusCurrent)
                    .frame(width: 8, height: 8)
                Text("Live Output · \(job.title)")
                    .font(TaproomTheme.mono(12, weight: .semibold))
                Spacer()
                if job.state == .running || job.state == .queued {
                    Button("Cancel Job", role: .destructive) {
                        appState.queue.cancel(jobID: job.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(TaproomTheme.surfaceElevated)

            Divider()
            LiveLogTextView(lines: job.logLines)
                .background(TaproomTheme.surface)
        }
    }
}
