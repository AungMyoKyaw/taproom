import SwiftUI

struct PackageInspectorView: View {
    @Environment(AppState.self) private var appState
    let package: BrewPackage?

    var body: some View {
        Group {
            if let pkg = package {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(pkg)
                        actionButtons(pkg)
                        metadataCard(pkg)
                        if !pkg.dependencies.isEmpty {
                            dependenciesSection(pkg)
                        }
                        if let caveats = pkg.caveats, !caveats.isEmpty {
                            caveatsSection(caveats)
                        }
                    }
                    .padding(20)
                }
                .background(TaproomTheme.surfaceElevated)
            } else {
                ContentUnavailableView(
                    "No Package Selected",
                    systemImage: "shippingbox",
                    description: Text("Select a formula or cask to inspect metadata, dependencies, and caveats.")
                )
                .background(TaproomTheme.surfaceElevated)
            }
        }
    }

    private func header(_ pkg: BrewPackage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(pkg.name)
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                KindBadge(kind: pkg.kind)
            }
            Text("\(pkg.version) · \(pkg.tap)")
                .font(TaproomTheme.mono(11, weight: .medium))
                .foregroundStyle(.secondary)

            if !pkg.description.isEmpty {
                Text(pkg.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
        }
    }

    private func actionButtons(_ pkg: BrewPackage) -> some View {
        HStack(spacing: 10) {
            if appState.outdatedIDs.contains(pkg.id) {
                Button {
                    appState.upgradePackage(name: pkg.name, kind: pkg.kind)
                } label: {
                    Label("Upgrade", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaproomTheme.accent)
            } else if pkg.kind == .formula {
                Button {
                    appState.togglePin(pkg)
                } label: {
                    Label(pkg.pinned ? "Unpin" : "Pin \(pkg.version)", systemImage: pkg.pinned ? "pin.slash" : "pin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                appState.uninstallPackage(pkg)
            } label: {
                Label("Uninstall", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func metadataCard(_ pkg: BrewPackage) -> some View {
        VStack(spacing: 10) {
            metaRow("Full Name", pkg.fullName)
            metaRow("Install Mode", pkg.installedOnRequest ? "Leaf (Requested)" : "Dependency")
            if let license = pkg.license {
                metaRow("License", license)
            }
            if !pkg.homepage.isEmpty {
                HStack(alignment: .top) {
                    Text("Homepage")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    if let url = URL(string: pkg.homepage) {
                        Link(pkg.homepage, destination: url)
                            .font(TaproomTheme.mono(11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text(pkg.homepage)
                            .font(TaproomTheme.mono(11))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(TaproomTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TaproomTheme.border, lineWidth: 1)
        )
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(TaproomTheme.mono(11))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func dependenciesSection(_ pkg: BrewPackage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEPENDENCIES (\(pkg.dependencies.count))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            FlowChipsView(items: pkg.dependencies)
        }
    }

    private func caveatsSection(_ caveats: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAVEATS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(caveats)
                .font(TaproomTheme.mono(11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TaproomTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TaproomTheme.border, lineWidth: 1)
                )
        }
    }
}

struct KindBadge: View {
    let kind: PackageKind

    var body: some View {
        Text(kind.badgeTitle)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(kind == .formula ? TaproomTheme.formulaBadgeFg : TaproomTheme.caskBadgeFg)
            .background(
                kind == .formula ? TaproomTheme.formulaBadgeBg : TaproomTheme.caskBadgeBg,
                in: RoundedRectangle(cornerRadius: 4)
            )
    }
}

private struct FlowChipsView: View {
    let items: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { dep in
                Text(dep)
                    .font(TaproomTheme.mono(11))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TaproomTheme.surface, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(TaproomTheme.border, lineWidth: 1)
                    )
            }
        }
    }
}
