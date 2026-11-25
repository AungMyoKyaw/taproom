import Foundation
import Testing
@testable import Taproom

@Suite("AskpassHelper Tests")
struct AskpassHelperTests {
    @Test("Creates executable askpass script without System Events TCC dependency")
    func createsExecutableDirectAskpassScript() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("taproom-askpass-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let path = try #require(AskpassHelper.ensureScriptPath(in: tempDir))
        #expect(FileManager.default.isExecutableFile(atPath: path))

        let contents = try String(contentsOfFile: path, encoding: .utf8)
        #expect(contents.contains("/usr/bin/osascript"))
        #expect(!contents.contains("System Events"))
    }
}
