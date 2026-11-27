import Foundation
import Testing
@testable import Taproom

@Suite("AppScanner Tests")
struct AppScannerTests {
    @Test("Detects architecture, skips Apple apps, and matches adoptable casks")
    func scansBundlesAndMatchesCasks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taproom-appscanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // 1. Unmanaged Rosetta app matching a cask in catalog
        try createMockApp(
            in: root,
            folderName: "Legacy Tool.app",
            bundleID: "com.example.legacytool",
            version: "2.1.0",
            executableName: "LegacyTool",
            machOHeader: thinMachOHeader(cpuType: 0x0100_0007) // x86_64
        )

        // 2. Managed ARM64 app already in installedCaskNames
        try createMockApp(
            in: root,
            folderName: "Ghostty.app",
            bundleID: "com.mitchellh.ghostty",
            version: "1.0.0",
            executableName: "ghostty",
            machOHeader: thinMachOHeader(cpuType: 0x0100_000C) // arm64
        )

        // 3. Universal app not in catalog
        try createMockApp(
            in: root,
            folderName: "Custom Universal.app",
            bundleID: "com.example.universal",
            version: "3.0.0",
            executableName: "CustomUniversal",
            machOHeader: fatMachOHeader(cpuTypes: [0x0100_000C, 0x0100_0007])
        )

        // 4. Apple system app (should be skipped)
        try createMockApp(
            in: root,
            folderName: "Safari.app",
            bundleID: "com.apple.Safari",
            version: "18.0",
            executableName: "Safari",
            machOHeader: thinMachOHeader(cpuType: 0x0100_000C)
        )

        let scanned = AppScanner.scan(
            directories: [root],
            installedCaskNames: ["ghostty"],
            caskLookup: ["legacytool": "legacy-tool"]
        )

        #expect(scanned.count == 3)
        #expect(!scanned.contains { $0.bundleIdentifier == "com.apple.Safari" })

        let legacy = try #require(scanned.first { $0.name == "Legacy Tool" })
        #expect(legacy.architecture == .x86_64)
        #expect(legacy.isRosetta)
        #expect(legacy.isAdoptable)
        #expect(legacy.matchedCaskToken == "legacy-tool")

        let ghostty = try #require(scanned.first { $0.name == "Ghostty" })
        #expect(ghostty.architecture == .arm64)
        #expect(ghostty.isManagedByBrew)
        #expect(!ghostty.isAdoptable)

        let universal = try #require(scanned.first { $0.name == "Custom Universal" })
        #expect(universal.architecture == .universal)
        #expect(!universal.isManagedByBrew)
        #expect(!universal.isAdoptable)
    }

    private func createMockApp(
        in dir: URL,
        folderName: String,
        bundleID: String,
        version: String,
        executableName: String,
        machOHeader: Data
    ) throws {
        let contents = dir.appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": folderName.replacingOccurrences(of: ".app", with: ""),
            "CFBundleShortVersionString": version,
            "CFBundleExecutable": executableName
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        try machOHeader.write(to: macOS.appendingPathComponent(executableName))
    }

    private func thinMachOHeader(cpuType: UInt32) -> Data {
        var data = Data()
        appendUInt32LE(&data, 0xFEED_FACF)
        appendUInt32LE(&data, cpuType)
        return data
    }

    private func fatMachOHeader(cpuTypes: [UInt32]) -> Data {
        var data = Data()
        appendUInt32BE(&data, 0xCAFE_BABE)
        appendUInt32BE(&data, UInt32(cpuTypes.count))
        for cpu in cpuTypes {
            appendUInt32BE(&data, cpu)
            data.append(Data(repeating: 0, count: 16))
        }
        return data
    }

    private func appendUInt32LE(_ data: inout Data, _ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private func appendUInt32BE(_ data: inout Data, _ value: UInt32) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }
}
