import SwiftUI

private struct PaletteCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let shortcut: String?
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    var body: some View {
        let commands = filteredCommands

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
                        .onSubmit {
                            executeSelected(in: commands)
                        }
                    Text("ESC")
                        .font(TaproomTheme.mono(10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: TaproomTheme.Radius.xs))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(TaproomTheme.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TaproomTheme.accent, lineWidth: 1.5)
                )
                .padding(12)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, cmd in
                                let isSelected = index == selectedIndex
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
                                                .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: TaproomTheme.Radius.xs))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? TaproomTheme.accent.opacity(0.12) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? TaproomTheme.accent : Color.clear, lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: selectedIndex) { _, newIdx in
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
            .frame(width: 600)
            .glassEffect(.regular, in: .rect(cornerRadius: TaproomTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: TaproomTheme.Radius.lg)
                    .stroke(TaproomTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onExitCommand { isPresented = false }
        .onKeyPress(.downArrow) {
            if !commands.isEmpty {
                selectedIndex = min(selectedIndex + 1, commands.count - 1)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if !commands.isEmpty {
                selectedIndex = max(selectedIndex - 1, 0)
            }
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected(in: commands)
            return .handled
        }
    }

    private func executeSelected(in commands: [PaletteCommand]) {
        guard commands.indices.contains(selectedIndex) else { return }
        isPresented = false
        commands[selectedIndex].action()
    }

    private var filteredCommands: [PaletteCommand] {
        var list: [PaletteCommand] = [
            PaletteCommand(
                id: "action.upgradeAll",
                title: "Upgrade All Outdated Packages (\(appState.outdatedPackages.count))",
                subtitle: "Action · Run brew upgrade",
                shortcut: "⌘U"
            ) { appState.upgradeAll() },
            PaletteCommand(
                id: "action.refreshAll",
                title: "Refresh Homebrew State",
                subtitle: "Action · Reload formulae, casks, services, taps",
                shortcut: "⌘R"
            ) { Task { await appState.refreshAll() } },
            PaletteCommand(
                id: "action.doctor",
                title: "Run brew doctor Diagnostics",
                subtitle: "Maintenance · System health",
                shortcut: nil
            ) { appState.runDoctor() },
            PaletteCommand(
                id: "action.missing",
                title: "Check Missing Dependencies (brew missing)",
                subtitle: "Maintenance · Verify formula dependencies",
                shortcut: nil
            ) { appState.runMissingCheck() },
            PaletteCommand(
                id: "action.adopt",
                title: "Scan & Adopt /Applications into Homebrew",
                subtitle: "Apps · Match local .app bundles to casks",
                shortcut: nil
            ) {
                appState.selectedSection = .adopt
                Task { await appState.scanLocalApplications() }
            },
            PaletteCommand(
                id: "action.maintenance",
                title: "Open Maintenance & Cache Cleanup (\(appState.formattedCacheSize))",
                subtitle: "Maintenance · Clean cache or run autoremove",
                shortcut: nil
            ) { appState.selectedSection = .maintenance },
            PaletteCommand(
                id: "action.inspector",
                title: "Toggle Package Inspector",
                subtitle: "View · Show or hide right detail pane",
                shortcut: "⌘I"
            ) { appState.inspectorPresented.toggle() },
        ]

        for section in SidebarSection.allCases {
            list.append(
                PaletteCommand(
                    id: "nav.\(section.rawValue)",
                    title: "Go to \(section.title)",
                    subtitle: "Navigation",
                    shortcut: nil
                ) { appState.selectedSection = section }
            )
        }

        for srv in appState.services {
            let verb = srv.status.isRunning ? "Stop" : "Start"
            list.append(
                PaletteCommand(
                    id: "srv.\(srv.name)",
                    title: "\(verb) Service \(srv.name)",
                    subtitle: "Service · \(srv.status.displayLabel)",
                    shortcut: nil
                ) {
                    appState.serviceAction(srv, action: verb.lowercased())
                }
            )
        }

        for pkg in appState.installedPackages {
            list.append(
                PaletteCommand(
                    id: "pkg.\(pkg.id)",
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
        return Array(
            list.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed)
                    || $0.subtitle.localizedCaseInsensitiveContains(trimmed)
            }.prefix(40)
        )
    }
}
