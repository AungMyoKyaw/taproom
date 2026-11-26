import SwiftUI

struct PackageInspectorView: View {
    @Environment(AppState.self) private var appState
    let package: BrewPackage?
    @State private var confirmUninstallPresented = false

    var body: some View {
        Group {
            if let pkg = package {
                let reverseDeps = appState.dependents(of: pkg.name)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(pkg)
                        actionButtons(pkg)
                        metadataCard(pkg)
                        if !pkg.dependencies.isEmpty {
                            chipSection(
                                title: "DEPENDENCIES (\(pkg.dependencies.count))",
                                items: pkg.dependencies
                            )
                        }
                        if !reverseDeps.isEmpty {
                            chipSection(
                                title: "REQUIRED BY (\(reverseDeps.count))",
                                items: reverseDeps.map(\.name)
                            )
                        }
                        if let caveats = pkg.caveats, !caveats.isEmpty {
                            caveatsSection(caveats)
                        }
                    }
                    .padding(20)
                }
                .background(TaproomTheme.surfaceElevated)
                .confirmationDialog(
                    "Uninstall \(pkg.name)?",
                    isPresented: $confirmUninstallPresented,
                    titleVisibility: .visible
                ) {
                    if pkg.kind == .cask {
                        Button("Uninstall", role: .destructive) {
                            appState.uninstallPackage(pkg, zap: false)
                        }
                        Button("Uninstall & Zap (Remove Settings & Cache)", role: .destructive) {
                            appState.uninstallPackage(pkg, zap: true)
                        }
                    } else {
                        Button("Uninstall \(pkg.name)", role: .destructive) {
                            appState.uninstallPackage(pkg, zap: false)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if pkg.kind == .cask {
                        Text("Zap removes app preferences, caches, and support files in addition to the cask.")
                    } else if !reverseDeps.isEmpty {
                        Text("Required by: \(reverseDeps.map(\.name).joined(separator: ", ")). Uninstalling may break those packages.")
                    } else {
                        Text("This runs brew uninstall \(pkg.name).")
                    }
                }
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
                .buttonStyle(TaproomPrimaryButtonStyle())
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
                confirmUninstallPresented = true
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
            if pkg.diskSizeBytes != nil {
                metaRow("Disk Size", pkg.formattedSize)
            }
            if let path = pkg.installedPath {
                metaRow("Path", path)
            }
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

    private func chipSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            FlowChipsView(items: items, installedNames: Set(appState.installedPackages.map(\.name))) { name in
                appState.selectPackage(named: name)
            }
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
    let installedNames: Set<String>
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { dep in
                let isInstalled = installedNames.contains(dep)
                Button {
                    if isInstalled { onSelect(dep) }
                } label: {
                    Text(dep)
                        .font(TaproomTheme.mono(11))
                        .foregroundStyle(isInstalled ? TaproomTheme.accent : .primary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TaproomTheme.surface, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isInstalled ? TaproomTheme.accent.opacity(0.35) : TaproomTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isInstalled)
            }
        }
    }
}
