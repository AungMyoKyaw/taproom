import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        ZStack {
            NavigationSplitView {
                sidebar
            } detail: {
                detailContent
                    .inspector(isPresented: $state.inspectorPresented) {
                        PackageInspectorView(package: appState.selectedPackage)
                            .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
                    }
            }
            .searchable(text: $state.searchText, placement: .toolbar, prompt: "Filter packages…")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await appState.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.isRefreshing)
                    .help("Refresh Homebrew state (⌘R)")

                    Button {
                        appState.commandPalettePresented.toggle()
                    } label: {
                        Label("Command Palette", systemImage: "command")
                    }
                    .help("Open Command Palette (⌘K)")

                    Button {
                        appState.inspectorPresented.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.right")
                    }
                    .help("Toggle Inspector (⌘I)")
                }
            }
            .overlay(alignment: .bottom) {
                if let active = appState.queue.activeJob {
                    JobQueuePill(job: active, queuedCount: appState.queue.queuedCount) {
                        appState.logSheetPresented = true
                    }
                    .padding(.bottom, 24)
                }
            }

            if appState.commandPalettePresented {
                CommandPaletteView(isPresented: $state.commandPalettePresented)
            }
        }
        .sheet(isPresented: $state.logSheetPresented) {
            LiveLogSheetView()
                .environment(appState)
        }
    }

    private var sidebar: some View {
        @Bindable var state = appState

        return List(selection: $state.selectedSection) {
            Section("Packages") {
                sidebarRow(.installed, badge: appState.installedPackages.count)
                sidebarRow(.outdated, badge: appState.outdatedPackages.count, accentBadge: true)
                sidebarRow(.discover, badge: nil)
            }
            Section("System") {
                sidebarRow(.services, badge: appState.services.filter { $0.status.isRunning }.count)
                sidebarRow(.taps, badge: appState.taps.count)
                sidebarRow(.maintenance, badge: nil)
                sidebarRow(.brewfile, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle()
                    .fill(TaproomTheme.statusCurrent)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(appState.prefixPath)
                        .font(TaproomTheme.mono(11, weight: .medium))
                    Text("Homebrew \(appState.brewVersion)")
                        .font(TaproomTheme.mono(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    }

    private func sidebarRow(_ section: SidebarSection, badge: Int?, accentBadge: Bool = false) -> some View {
        HStack {
            Label(section.title, systemImage: section.systemImage)
            Spacer()
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(TaproomTheme.mono(10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        accentBadge ? TaproomTheme.accent : Color.secondary.opacity(0.18),
                        in: Capsule()
                    )
                    .foregroundStyle(accentBadge ? TaproomTheme.onAccent : .secondary)
            }
        }
        .tag(section)
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(spacing: 0) {
            if let error = appState.lastError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TaproomTheme.statusError)
                    Text(error)
                        .font(TaproomTheme.mono(11))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Spacer()
                    Button("Dismiss") {
                        appState.dismissError()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(TaproomTheme.statusError.opacity(0.12))
                Divider()
            }

            Group {
                switch appState.selectedSection {
                case .installed: InstalledPackagesView()
                case .outdated: OutdatedView()
                case .discover: DiscoverView()
                case .services: ServicesView()
                case .taps: TapsView()
                case .maintenance: MaintenanceView()
                case .brewfile: BrewfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct JobQueuePill: View {
    let job: MutationJob
    let queuedCount: Int
    let onTap: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(job.title)
                            .font(.system(size: 12, weight: .semibold))
                        Text(queuedCount > 0 ? "\(queuedCount) more queued · Click for logs" : "Running · Click for live logs")
                            .font(TaproomTheme.mono(10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: TaproomTheme.Radius.lg))
        }
    }
}

private struct LiveLogSheetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            let job = appState.queue.activeJob ?? appState.queue.jobs.last
            HStack(spacing: 10) {
                Text(job?.title ?? "Job Output")
                    .font(TaproomTheme.mono(13, weight: .semibold))
                if let job {
                    JobElapsedTimerView(job: job)
                }
                Spacer()
                if let job, job.state == .running || job.state == .queued {
                    Button("Cancel Job", role: .destructive) {
                        appState.queue.cancel(jobID: job.id)
                    }
                    .buttonStyle(.bordered)
                }
                Button("Close") { dismiss() }
                    .buttonStyle(TaproomPrimaryButtonStyle())
            }
            .padding(16)
            Divider()
            LiveLogTextView(jobID: job?.id, lines: job?.logLines ?? ["No active or recent job output."])
                .background(TaproomTheme.surface)
        }
        .frame(width: 780, height: 480)
    }
}
