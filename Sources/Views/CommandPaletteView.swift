import SwiftUI

private struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let shortcut: String?
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(TaproomTheme.accent)
                    TextField("Type a command, package, or service…", text: $query)
                        .textFieldStyle(.plain)
                        .font(TaproomTheme.mono(14))
                        .focused($searchFocused)
                    Text("ESC")
                        .font(TaproomTheme.mono(10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(14)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredCommands) { cmd in
                            Button {
                                isPresented = false
                                cmd.action()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(cmd.title)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(cmd.subtitle)
                                            .font(TaproomTheme.mono(11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let shortcut = cmd.shortcut {
                                        Text(shortcut)
                                            .font(TaproomTheme.mono(11))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 5))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 340)
            }
            .frame(width: 600)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(TaproomTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .onAppear { searchFocused = true }
        .onExitCommand { isPresented = false }
    }

    private var filteredCommands: [PaletteCommand] {
        var list: [PaletteCommand] = [
            PaletteCommand(
                title: "Upgrade All Outdated Packages (\(appState.outdatedPackages.count))",
                subtitle: "Action · Run brew upgrade",
                shortcut: "⌘U"
            ) { appState.upgradeAll() },
            PaletteCommand(
                title: "Refresh Homebrew State",
                subtitle: "Action · Reload formulae, casks, services, taps",
                shortcut: "⌘R"
            ) { Task { await appState.refreshAll() } },
            PaletteCommand(
                title: "Run brew doctor Diagnostics",
                subtitle: "Maintenance · System health",
                shortcut: nil
            ) { appState.runDoctor() },
            PaletteCommand(
                title: "Clean Homebrew Cache (\(appState.formattedCacheSize))",
                subtitle: "Maintenance · brew cleanup --prune=all",
                shortcut: nil
            ) { appState.cleanCache() },
            PaletteCommand(
                title: "Toggle Package Inspector",
                subtitle: "View · Show or hide right detail pane",
                shortcut: "⌘I"
            ) { appState.inspectorPresented.toggle() },
        ]

        for section in SidebarSection.allCases {
            list.append(
                PaletteCommand(
                    title: "Go to \(section.title)",
                    subtitle: "Navigation",
                    shortcut: nil
                ) { appState.selectedSection = section }
            )
        }

        for pkg in appState.installedPackages.prefix(40) {
            list.append(
                PaletteCommand(
                    title: "Inspect \(pkg.name) (\(pkg.version))",
                    subtitle: "\(pkg.kind.badgeTitle) · \(pkg.tap)",
                    shortcut: nil
                ) {
                    appState.selectedSection = .installed
                    appState.selectedPackageID = pkg.id
                    appState.inspectorPresented = true
                }
            )
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(list.prefix(12)) }
        return list.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.subtitle.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
