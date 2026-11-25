import SwiftUI

@main
struct TaproomApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 1080, minHeight: 700)
                .onAppear {
                    appState.startInitialLoad()
                }
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    appState.commandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Toggle Inspector") {
                    appState.inspectorPresented.toggle()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Live Logs") {
                    appState.logSheetPresented.toggle()
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button("Refresh All") {
                    Task { await appState.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Upgrade All Outdated") {
                    appState.upgradeAll()
                }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(appState.outdatedPackages.isEmpty)
            }
        }

        MenuBarExtra {
            MenuBarPopoverView {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .environment(appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mug.fill")
                if !appState.outdatedPackages.isEmpty {
                    Text("\(appState.outdatedPackages.count)")
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
