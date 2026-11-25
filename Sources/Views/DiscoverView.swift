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
                    ProgressView("Indexing Homebrew Formulae & Casks into SQLite FTS5…")
                    Button("Sync Catalog Now") {
                        Task {
                            await appState.syncCatalog()
                            scheduleSearch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TaproomTheme.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TaproomTheme.surface)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(results) { entry in
                            let installed = appState.installedIDs.contains(entry.id)
                            DiscoverRow(
                                entry: entry,
                                isInstalled: installed,
                                onInstall: {
                                    appState.installPackage(name: entry.name, kind: entry.kind)
                                },
                                onInspectInstalled: {
                                    appState.selectPackage(named: entry.name)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
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

private struct DiscoverRow: View {
    let entry: CatalogEntry
    let isInstalled: Bool
    let onInstall: () -> Void
    let onInspectInstalled: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .bold))
                    KindBadge(kind: entry.kind)
                    Text("\(entry.version) · \(entry.tap)")
                        .font(TaproomTheme.mono(11))
                        .foregroundStyle(.secondary)
                    if let url = URL(string: entry.homepage), !entry.homepage.isEmpty {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .help(entry.homepage)
                    }
                }
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if isInstalled {
                Button(action: onInspectInstalled) {
                    Label("Installed", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TaproomTheme.statusCurrent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TaproomTheme.statusCurrent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Inspect installed package")
            } else {
                Button("Install", action: onInstall)
                    .buttonStyle(.borderedProminent)
                    .tint(TaproomTheme.accent)
            }
        }
        .taproomCard()
    }
}
