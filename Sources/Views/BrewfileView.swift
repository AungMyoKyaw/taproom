import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BrewfileView: View {
    @Environment(AppState.self) private var appState
    @State private var statusMessage: String?

    var body: some View {
        let content = appState.generateBrewfileText()

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Live Brewfile Preview")
                    .font(.system(size: 13, weight: .semibold))
                if let statusMessage {
                    Text(statusMessage)
                        .font(TaproomTheme.mono(11))
                        .foregroundStyle(TaproomTheme.statusCurrent)
                }
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                    statusMessage = "Copied to clipboard"
                }
                .buttonStyle(.bordered)

                Button("Import Brewfile…") {
                    chooseAndImportBrewfile()
                }
                .buttonStyle(.bordered)

                Button("Export to ~/Brewfile") {
                    exportHomeBrewfile(content)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaproomTheme.accent)
            }
            .padding(16)
            Divider()

            ScrollView {
                Text(content)
                    .font(TaproomTheme.mono(12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(TaproomTheme.surfaceElevated)
        }
        .background(TaproomTheme.surface)
    }

    private func exportHomeBrewfile(_ content: String) {
        let dest = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Brewfile")
        do {
            try content.write(to: dest, atomically: true, encoding: .utf8)
            statusMessage = "Saved \(dest.path)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func chooseAndImportBrewfile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .data]
        if panel.runModal() == .OK, let url = panel.url {
            appState.importBrewfile(at: url)
        }
    }
}
