import Foundation
import Testing
@testable import Taproom

@Suite("BrewOutputParser Tests")
struct BrewOutputParserTests {
    @Test("Extracts JSON payload after leading warning lines")
    func extractJSONWithLeadingWarnings() throws {
        let raw = """
        Warning: Calling string comparison format for `depends_on macos:` is deprecated!
        Report this issue to the tap.
        {"formulae":[],"casks":[]}
        """
        let data = BrewOutputParser.extractJSONPayload(from: raw)
        #expect(data != nil)
        let packages = try BrewOutputParser.parseInstalledInfo(raw)
        #expect(packages.isEmpty)
    }

    @Test("Parses installed formulae and casks with leaf/dependency status")
    func parseInstalledFormulaeAndCasks() throws {
        let json = """
        {
          "formulae": [
            {
              "name": "ripgrep",
              "full_name": "ripgrep",
              "tap": "homebrew/core",
              "desc": "Search tool like grep",
              "homepage": "https://github.com/BurntSushi/ripgrep",
              "license": "MIT",
              "versions": { "stable": "14.1.1" },
              "installed": [{ "version": "14.1.1", "installed_on_request": true }],
              "dependencies": ["pcre2"],
              "caveats": "None",
              "pinned": false
            },
            {
              "name": "pcre2",
              "full_name": "pcre2",
              "tap": "homebrew/core",
              "desc": "Perl compatible regex",
              "homepage": "https://pcre.org",
              "license": "BSD-3-Clause",
              "versions": { "stable": "10.45" },
              "installed": [{ "version": "10.45", "installed_on_request": false }],
              "dependencies": [],
              "caveats": null,
              "pinned": true
            }
          ],
          "casks": [
            {
              "token": "ghostty",
              "full_token": "ghostty",
              "name": ["Ghostty"],
              "tap": "homebrew/cask",
              "desc": "Terminal emulator",
              "homepage": "https://ghostty.org",
              "version": "1.1.3",
              "installed": "1.1.3",
              "caveats": null
            }
          ]
        }
        """
        let parsed = try BrewOutputParser.parseInstalledInfo(json)
        #expect(parsed.count == 3)
        let rg = try #require(parsed.first { $0.name == "ripgrep" })
        #expect(rg.kind == .formula)
        #expect(rg.installedOnRequest == true)
        #expect(rg.dependencies == ["pcre2"])

        let pcre = try #require(parsed.first { $0.name == "pcre2" })
        #expect(pcre.installedOnRequest == false)
        #expect(pcre.pinned == true)

        let ghostty = try #require(parsed.first { $0.name == "ghostty" })
        #expect(ghostty.kind == .cask)
        #expect(ghostty.version == "1.1.3")
    }

    @Test("Parses outdated formulae and casks")
    func parseOutdated() throws {
        let json = """
        {
          "formulae": [
            { "name": "ffmpeg", "installed_versions": ["7.1"], "current_version": "7.1.1", "pinned": false }
          ],
          "casks": [
            { "name": "raycast", "installed_versions": ["1.94.0"], "current_version": "1.94.2" }
          ]
        }
        """
        let outdated = try BrewOutputParser.parseOutdated(json)
        #expect(outdated.count == 2)
        #expect(outdated[0].name == "ffmpeg")
        #expect(outdated[0].availableVersion == "7.1.1")
        #expect(outdated[1].kind == .cask)
    }

    @Test("Parses services and taps JSON")
    func parseServicesAndTaps() throws {
        let srvJSON = """
        [{"name":"postgresql@17","status":"started","user":"dev","file":"/opt/homebrew/opt/postgresql@17/plist","exit_code":null}]
        """
        let services = try BrewOutputParser.parseServices(srvJSON)
        #expect(services.count == 1)
        #expect(services[0].status == .started)

        let tapJSON = """
        [{"name":"homebrew/core","official":true,"path":"/opt/homebrew/Library/Taps/homebrew/homebrew-core","formula_names":["ripgrep","git"],"cask_tokens":[]}]
        """
        let taps = try BrewOutputParser.parseTaps(tapJSON)
        #expect(taps.count == 1)
        #expect(taps[0].official == true)
        #expect(taps[0].formulaCount == 2)
    }

    @Test("Parses Brewfile lines")
    func parseBrewfile() {
        let text = """
        # Comment
        tap "homebrew/cask"
        brew "ripgrep"
        cask 'ghostty'
        """
        let parsed = BrewOutputParser.parseBrewfile(text)
        #expect(parsed.taps == ["homebrew/cask"])
        #expect(parsed.formulae == ["ripgrep"])
        #expect(parsed.casks == ["ghostty"])
    }
}
