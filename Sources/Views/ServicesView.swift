import SwiftUI

struct ServicesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("BACKGROUND SERVICES (brew services)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if appState.services.isEmpty {
                    ContentUnavailableView(
                        "No Homebrew Services",
                        systemImage: "gearshape.2",
                        description: Text("Install a service-enabled formula such as postgresql@17 or redis.")
                    )
                } else {
                    ForEach(appState.services) { service in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(service.status.isRunning ? TaproomTheme.statusCurrent : Color.secondary.opacity(0.45))
                                .frame(width: 9, height: 9)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(service.name)
                                    .font(TaproomTheme.mono(13, weight: .semibold))
                                Text(serviceSubtitle(service))
                                    .font(TaproomTheme.mono(11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()

                            if service.status.isRunning {
                                Button("Restart") {
                                    appState.serviceAction(service, action: "restart")
                                }
                                .buttonStyle(.bordered)

                                Button("Stop", role: .destructive) {
                                    appState.serviceAction(service, action: "stop")
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Start") {
                                    appState.serviceAction(service, action: "start")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(TaproomTheme.accent)
                            }
                        }
                        .taproomCard()
                    }
                }
            }
            .padding(20)
        }
        .background(TaproomTheme.surface)
    }

    private func serviceSubtitle(_ service: BrewServiceInfo) -> String {
        var parts = [service.status.displayLabel]
        if let user = service.user { parts.append("user: \(user)") }
        if let file = service.file { parts.append(file) }
        return parts.joined(separator: " · ")
    }
}
