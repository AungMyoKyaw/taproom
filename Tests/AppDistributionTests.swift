import Testing
@testable import Taproom

@Suite("AppDistribution Tests")
struct AppDistributionTests {
    @Test("Detects Homebrew Caskroom paths accurately")
    func detectsCaskroomInstall() {
        #expect(AppDistribution.isInstalledViaHomebrewCask(bundlePath: "/opt/homebrew/Caskroom/taproom/0.2.0/Taproom.app"))
        #expect(AppDistribution.isInstalledViaHomebrewCask(bundlePath: "/usr/local/Caskroom/taproom/0.2.0/Taproom.app"))
        #expect(!AppDistribution.isInstalledViaHomebrewCask(bundlePath: "/Applications/Taproom.app"))
    }
}
