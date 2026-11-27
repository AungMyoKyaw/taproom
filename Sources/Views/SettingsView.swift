import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Updates & Refresh") {
                Picker("Background Check Interval", selection: $state.checkIntervalHours) {
                    Text("Every 1 hour").tag(1)
                    Text("Every 6 hours").tag(6)
                    Text("Every 12 hours").tag(12)
                    Text("Every 24 hours").tag(24)
                }
                Toggle("Notify when outdated packages are found", isOn: $state.notifyOnOutdated)
                Toggle("Include auto-updating casks (--greedy)", isOn: $state.includeGreedyCasks)
            }

            Section("Network & Binary Overrides") {
                TextField("Custom brew path (leave empty for auto)", text: $state.customBrewPath)
                    .font(TaproomTheme.monoSm)
                TextField("HTTP/HTTPS proxy (e.g. http://127.0.0.1:8080)", text: $state.httpProxy)
                    .font(TaproomTheme.monoSm)
            }

            Section("Homebrew Environment") {
                LabeledContent("Binary", value: appState.runner.brewPath)
                LabeledContent("Prefix", value: appState.prefixPath)
                LabeledContent("Version", value: appState.brewVersion)
                LabeledContent("Catalog Indexed", value: "\(appState.catalogCount) entries")
                LabeledContent(
                    "Distribution",
                    value: AppDistribution.isInstalledViaHomebrewCask() ? "Homebrew Cask" : "Standalone App"
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 420)
    }
}
