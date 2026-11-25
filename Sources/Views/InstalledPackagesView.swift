import SwiftUI

struct InstalledPackagesView: View {
    @Environment(AppState.self) private var appState
    @State private var sortOrder = [KeyPathComparator(\BrewPackage.name)]

    private var sortedPackages: [BrewPackage] {
        appState.filteredInstalledPackages.sorted(using: sortOrder)
    }

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            filterBar
            Divider()
            if appState.installedPackages.isEmpty && appState.isRefreshing {
                ProgressView("Loading Homebrew Cellar & Caskroom…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TaproomTheme.surface)
            } else {
                Table(sortedPackages, selection: $state.selectedPackageID, sortOrder: $sortOrder) {
                    TableColumn("Package", value: \.name) { pkg in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pkg.name)
                                .font(.system(size: 13, weight: .medium))
                            if !pkg.description.isEmpty {
                                Text(pkg.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .width(min: 190, ideal: 260)

                    TableColumn("Kind", value: \.sortableKind) { pkg in
                        KindBadge(kind: pkg.kind)
                    }
                    .width(78)

                    TableColumn("Version", value: \.version) { pkg in
                        let isOutdated = appState.outdatedIDs.contains(pkg.id)
                        Text(pkg.version)
                            .font(TaproomTheme.mono(12, weight: .medium))
                            .foregroundStyle(isOutdated ? TaproomTheme.statusOutdated : .secondary)
                    }
                    .width(min: 95, ideal: 130)

                    TableColumn("Size", value: \.sortableSize) { pkg in
                        Text(pkg.formattedSize)
                            .font(TaproomTheme.mono(11))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 70, ideal: 86)

                    TableColumn("Tap", value: \.tap) { pkg in
                        Text(pkg.tap)
                            .font(TaproomTheme.mono(11))
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 105, ideal: 140)

                    TableColumn("Status", value: \.sortableStatus) { pkg in
                        let isOutdated = appState.outdatedIDs.contains(pkg.id)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isOutdated ? TaproomTheme.statusOutdated : TaproomTheme.statusCurrent)
                                .frame(width: 7, height: 7)
                            Text(isOutdated ? "Outdated" : (pkg.pinned ? "Pinned" : "Current"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isOutdated ? TaproomTheme.statusOutdated : .secondary)
                        }
                    }
                    .width(92)
                }
                .scrollContentBackground(.hidden)
                .background(TaproomTheme.surface)
            }
        }
        .background(TaproomTheme.surface)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(InstalledFilter.allCases) { filter in
                let isSelected = appState.installedFilter == filter
                Button {
                    appState.installedFilter = filter
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
            Text("\(appState.filteredInstalledPackages.count) shown")
                .font(TaproomTheme.mono(11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TaproomTheme.surface)
    }

    private func filterTitle(_ filter: InstalledFilter) -> String {
        switch filter {
        case .all: "All (\(appState.installedPackages.count))"
        case .leaves: "Leaves (\(appState.installedPackages.filter(\.installedOnRequest).count))"
        case .formulae: "Formulae (\(appState.installedPackages.filter { $0.kind == .formula }.count))"
        case .casks: "Casks (\(appState.installedPackages.filter { $0.kind == .cask }.count))"
        }
    }
}
