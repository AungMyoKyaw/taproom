import Foundation

enum AskpassHelper {
    static let scriptContents = """
    #!/bin/zsh
    /usr/bin/osascript -e 'display dialog "Taproom needs administrator privileges to install or update a Homebrew package." default answer "" with hidden answer with title "Taproom Authentication" buttons {"Cancel", "OK"} default button "OK"' -e 'text returned of result' 2>/dev/null
    """

    /// Ensures an executable `SUDO_ASKPASS` script exists in Application Support
    /// that prompts the user via a direct `osascript` dialog when a cask requires sudo.
    static func ensureScriptPath(in directory: URL? = nil) -> String? {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                return nil
            }
            dir = appSupport.appendingPathComponent("Taproom", isDirectory: true)
        }
        let scriptURL = dir.appendingPathComponent("askpass.sh")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try scriptContents.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return nil
        }
    }
}
