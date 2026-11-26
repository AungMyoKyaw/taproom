import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var query: String = ""
    @State private var kindFilter: PackageKind? = nil
    @State private var results: [CatalogEntry] = []
    @State private var elapsedMs: Double = 0
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
            if appState.catalogCount == 0 {
                VStack(spacing: 12) {
                    if appState.isSyncingCatalog {
                        ProgressView("Indexing Homebrew Formulae & Casks into SQLite FTS5…")
                    } else {
                        Text("Catalog not indexed yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Button("Sync Catalog Now") {
                        Task {
                            await appState.syncCatalog()
                            scheduleSearch()
                        }
                    }
                    .buttonStyle(TaproomPrimaryButtonStyle())
                    .disabled(appState.isSyncingCatalog)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TaproomTheme.surface)
            } else {
                Table(results) {
                    TableColumn("Package") { entry in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name)
                                .font(.system(size: 13, weight: .medium))
                            if !entry.description.isEmpty {
                                Text(entry.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .width(min: 220, ideal: 340)

                    TableColumn("Kind") { entry in
                        KindBadge(kind: entry.kind)
                    }
                    .width(78)

                    TableColumn("Version") { entry in
                        Text(entry.version)
                            .font(TaproomTheme.monoMd)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 95, ideal: 130)

                    TableColumn("Tap") { entry in
                        Text(entry.tap)
                            .font(TaproomTheme.monoSm)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 110, ideal: 150)

                    TableColumn("Action") { entry in
                        let installed = appState.installedIDs.contains(entry.id)
                        if installed {
                            Button {
                                appState.selectPackage(named: entry.name)
                            } label: {
                                Label("Installed", systemImage: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(TaproomTheme.statusCurrent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(TaproomTheme.statusCurrent.opacity(0.12), in: RoundedRectangle(cornerRadius: TaproomTheme.Radius.sm))
                            }
                            .buttonStyle(.plain)
                            .help("Inspect installed package")
                        } else {
                            Button("Install") {
                                appState.installPackage(name: entry.name, kind: entry.kind)
                            }
                            .buttonStyle(TaproomPrimaryButtonStyle())
                        }
                    }
                    .width(96)
                }
                .scrollContentBackground(.hidden)
                .background(TaproomTheme.surface)
            }
        }
        .onAppear { scheduleSearch(immediate: true) }
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onChange(of: kindFilter) { _, _ in scheduleSearch(immediate: true) }
        .onChange(of: appState.catalogCount) { _, _ in scheduleSearch(immediate: true) }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TaproomTheme.accent)
                TextField("Search \(appState.catalogCount) formulae & casks (FTS5 BM25)…", text: $query)
                    .textFieldStyle(.plain)
                    .font(TaproomTheme.mono(14))
                Text(String(format: "%d matches · %.1f ms", results.count, elapsedMs))
                    .font(TaproomTheme.mono(11))
                    .foregroundStyle(.secondary)
                Button {
                    Task { await appState.syncCatalog() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(appState.isSyncingCatalog)
                .help("Sync catalog from formulae.brew.sh")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TaproomTheme.accent.opacity(0.6), lineWidth: 1.5)
            )

            HStack(spacing: 8) {
                filterPill("All", selected: kindFilter == nil) { kindFilter = nil }
                filterPill("Formulae", selected: kindFilter == .formula) { kindFilter = .formula }
                filterPill("Casks", selected: kindFilter == .cask) { kindFilter = .cask }
                Spacer()
            }
        }
        .padding(16)
        .background(TaproomTheme.surface)
    }

    private func filterPill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? TaproomTheme.accent.opacity(0.16) : TaproomTheme.surfaceElevated, in: Capsule())
                .overlay(Capsule().stroke(selected ? TaproomTheme.accent : TaproomTheme.border, lineWidth: 1))
                .foregroundStyle(selected ? TaproomTheme.accent : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        guard let catalog = appState.catalog else { return }
        let currentQuery = query
        let currentKind = kindFilter

        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(80))
            }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) {
                try? catalog.search(query: currentQuery, kind: currentKind, limit: 80)
            }.value
            guard !Task.isCancelled, let result else { return }
            self.results = result.entries
            self.elapsedMs = result.elapsedMs
        }
    }
}
