import SwiftUI

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    let onOpenMainWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Taproom")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(appState.outdatedPackages.count) Outdated")
                    .font(TaproomTheme.mono(11, weight: .semibold))
                    .foregroundStyle(appState.outdatedPackages.isEmpty ? TaproomTheme.statusCurrent : TaproomTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (appState.outdatedPackages.isEmpty ? TaproomTheme.statusCurrent : TaproomTheme.accent).opacity(0.15),
                        in: Capsule()
                    )
            }

            Button {
                appState.upgradeAll()
            } label: {
                Text(appState.outdatedPackages.isEmpty ? "All Packages Up to Date" : "Upgrade All (\(appState.outdatedPackages.count))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TaproomPrimaryButtonStyle())
            .disabled(appState.outdatedPackages.isEmpty)

            if !appState.services.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SERVICES")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(appState.services.prefix(5)) { srv in
                        HStack {
                            Circle()
                                .fill(srv.status.isRunning ? TaproomTheme.statusCurrent : Color.secondary.opacity(0.45))
                                .frame(width: 7, height: 7)
                            Text(srv.name)
                                .font(TaproomTheme.mono(12))
                            Spacer()
                            Button(srv.status.isRunning ? "Stop" : "Start") {
                                appState.serviceAction(srv, action: srv.status.isRunning ? "stop" : "start")
                            }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TaproomTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }

            Divider()

            Button("Open Taproom Cockpit") {
                onOpenMainWindow()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 310)
    }
}
