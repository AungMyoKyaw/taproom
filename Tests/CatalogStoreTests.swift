import Testing
@testable import Taproom

@Suite("CatalogStore FTS5 Tests")
struct CatalogStoreTests {
    @Test("Indexes entries and performs ranked FTS5 search with kind filter")
    func fts5SearchAndFilter() throws {
        let store = try CatalogStore(inMemory: true)
        let entries = [
            CatalogEntry(id: "formula:httpie", name: "httpie", fullName: "httpie", kind: .formula, version: "3.2.4", tap: "homebrew/core", description: "User-friendly cURL replacement HTTP client", homepage: "https://httpie.io"),
            CatalogEntry(id: "cask:proxyman", name: "proxyman", fullName: "proxyman", kind: .cask, version: "5.15.0", tap: "homebrew/cask", description: "Native HTTP debugging proxy", homepage: "https://proxyman.io"),
            CatalogEntry(id: "formula:ripgrep", name: "ripgrep", fullName: "ripgrep", kind: .formula, version: "14.1.1", tap: "homebrew/core", description: "Fast line-oriented search tool", homepage: "https://github.com/BurntSushi/ripgrep"),
        ]
        try store.replaceAll(entries)
        #expect(try store.count() == 3)

        let allHttp = try store.search(query: "http", kind: nil, limit: 20)
        #expect(allHttp.entries.count == 2)

        let casksOnly = try store.search(query: "http", kind: .cask, limit: 20)
        #expect(casksOnly.entries.count == 1)
        #expect(casksOnly.entries[0].name == "proxyman")
    }
}
