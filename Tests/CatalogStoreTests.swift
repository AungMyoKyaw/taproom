import Foundation
import GRDB
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

    @Test("Repairs legacy v1_catalog FTS triggers missing old.name on delete/update")
    func repairsLegacyV1Triggers() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("taproom-legacy-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let legacyQueue = try DatabaseQueue(path: tempURL.path)
        var legacyMigrator = DatabaseMigrator()
        legacyMigrator.registerMigration("v1_catalog") { db in
            try db.create(table: "catalog_entries") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("fullName", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("version", .text).notNull()
                t.column("tap", .text).notNull()
                t.column("description", .text).notNull()
                t.column("homepage", .text).notNull()
            }
            try db.execute(sql: """
                CREATE VIRTUAL TABLE catalog_fts USING fts5(
                    id UNINDEXED, name, fullName, description, tap,
                    content='catalog_entries', content_rowid='rowid'
                );
                CREATE TRIGGER catalog_ai AFTER INSERT ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(rowid, id, name, fullName, description, tap)
                    VALUES (new.rowid, new.id, new.name, new.fullName, new.description, new.tap);
                END;
                CREATE TRIGGER catalog_ad AFTER DELETE ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(catalog_fts, rowid, id, name, fullName, description, tap)
                    VALUES ('delete', old.rowid, old.id, old.fullName, old.description, old.tap);
                END;
                CREATE TRIGGER catalog_au AFTER UPDATE ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(catalog_fts, rowid, id, name, fullName, description, tap)
                    VALUES ('delete', old.rowid, old.id, old.fullName, old.description, old.tap);
                    INSERT INTO catalog_fts(rowid, id, name, fullName, description, tap)
                    VALUES (new.rowid, new.id, new.name, new.fullName, new.description, new.tap);
                END;
                INSERT INTO catalog_entries (id, name, fullName, kind, version, tap, description, homepage)
                VALUES ('formula:old', 'old', 'old', 'formula', '1.0', 'homebrew/core', 'Legacy row', '');
                """)
        }
        try legacyMigrator.migrate(legacyQueue)

        let store = try CatalogStore(databasePath: tempURL.path)
        try store.replaceAll([
            CatalogEntry(id: "formula:ripgrep", name: "ripgrep", fullName: "ripgrep", kind: .formula, version: "14.1.1", tap: "homebrew/core", description: "Fast search", homepage: "")
        ])
        #expect(try store.count() == 1)
        let hits = try store.search(query: "ripgrep", kind: nil, limit: 10)
        #expect(hits.entries.count == 1)
    }
}
