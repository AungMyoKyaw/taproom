import SwiftUI

struct TapsView: View {
    @Environment(AppState.self) private var appState
    @State private var newTapName: String = ""
    @State private var tapToRemove: BrewTapInfo?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Add tap (e.g. homebrew/cask-fonts or user/tap)", text: $newTapName)
                    .textFieldStyle(.roundedBorder)
                    .font(TaproomTheme.mono(12))
                Button("Add Tap") {
                    appState.addTap(newTapName)
                    newTapName = ""
                }
                .buttonStyle(TaproomPrimaryButtonStyle())
                .disabled(newTapName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(appState.taps) { tap in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(tap.name)
                                        .font(TaproomTheme.mono(13, weight: .semibold))
                                    if tap.official {
                                        Text("OFFICIAL")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(TaproomTheme.statusCurrent.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                                            .foregroundStyle(TaproomTheme.statusCurrent)
                                    }
                                }
                                Text("\(tap.formulaCount) formulae · \(tap.caskCount) casks")
                                    .font(TaproomTheme.mono(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !tap.official {
                                Button("Untap", role: .destructive) {
                                    tapToRemove = tap
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .taproomCard()
                    }
                }
                .padding(16)
            }
        }
        .background(TaproomTheme.surface)
        .confirmationDialog(
            "Untap \(tapToRemove?.name ?? "")?",
            isPresented: Binding(
                get: { tapToRemove != nil },
                set: { if !$0 { tapToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let tap = tapToRemove {
                Button("Untap \(tap.name)", role: .destructive) {
                    appState.removeTap(tap.name)
                    tapToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) { tapToRemove = nil }
        } message: {
            Text("Removes the tap repository from Homebrew.")
        }
    }
}
