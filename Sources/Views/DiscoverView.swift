import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var query: String = ""
    @State private var kindFilter: PackageKind? = nil
    @State private var results: [CatalogEntry] = []
    @State private var elapsedMs: Double = 0

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
                            runSearch()
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
                            DiscoverRow(
                                entry: entry,
                                isInstalled: appState.installedIDs.contains(entry.id)
                            ) {
                                appState.installPackage(name: entry.name, kind: entry.kind)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(TaproomTheme.surface)
            }
        }
        .onAppear { runSearch() }
        .onChange(of: query) { _, _ in runSearch() }
        .onChange(of: kindFilter) { _, _ in runSearch() }
        .onChange(of: appState.catalogCount) { _, _ in runSearch() }
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

    private func runSearch() {
        guard let catalog = appState.catalog else { return }
        if let res = try? catalog.search(query: query, kind: kindFilter, limit: 80) {
            self.results = res.entries
            self.elapsedMs = res.elapsedMs
        }
    }
}

private struct DiscoverRow: View {
    let entry: CatalogEntry
    let isInstalled: Bool
    let onInstall: () -> Void

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
                Label("Installed", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TaproomTheme.statusCurrent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TaproomTheme.statusCurrent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            } else {
                Button("Install", action: onInstall)
                    .buttonStyle(.borderedProminent)
                    .tint(TaproomTheme.accent)
            }
        }
        .padding(14)
        .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TaproomTheme.border, lineWidth: 1)
        )
    }
}
