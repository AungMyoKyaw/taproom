import Foundation

enum AskpassHelper {
    /// Ensures an executable `SUDO_ASKPASS` script exists in Application Support
    /// that prompts the user via native macOS AppleScript dialog when a cask requires sudo.
    static func ensureScriptPath() -> String? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Taproom", isDirectory: true)
        let scriptURL = dir.appendingPathComponent("askpass.sh")
        let script = """
        #!/bin/zsh
        /usr/bin/osascript -e 'Tell application "System Events" to display dialog "Taproom needs administrator privileges to install or update a Homebrew package." default answer "" with hidden answer with title "Taproom Authentication"' -e 'text returned of result' 2>/dev/null
        """
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return nil
        }
    }
}
