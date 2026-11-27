import Foundation

enum AppDistribution {
    /// Returns true when the app bundle is running out of a Homebrew Caskroom directory.
    /// In that mode, in-app self-updaters should defer to `brew upgrade --cask`.
    static func isInstalledViaHomebrewCask(bundlePath: String = Bundle.main.bundlePath) -> Bool {
        let resolved = URL(fileURLWithPath: bundlePath).resolvingSymlinksInPath().path
        return resolved.contains("/Caskroom/") || bundlePath.contains("/Caskroom/")
    }

    static var hostArchitecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}
