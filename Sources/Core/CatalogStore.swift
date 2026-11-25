import Foundation
import GRDB

struct CatalogSearchResult: Sendable {
    let entries: [CatalogEntry]
    let elapsedMs: Double
}

final class CatalogStore: Sendable {
    private let dbQueue: DatabaseQueue

    init(inMemory: Bool = false) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            if !inMemory {
                try db.execute(sql: "PRAGMA journal_mode = WAL;")
            }
        }
        if inMemory {
            self.dbQueue = try DatabaseQueue(configuration: config)
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("Taproom", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbPath = dir.appendingPathComponent("catalog.sqlite").path
            self.dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
        }
        try Self.migrate(dbQueue)
    }

    private static func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_catalog") { db in
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
                    id UNINDEXED,
                    name,
                    fullName,
                    description,
                    tap,
                    content='catalog_entries',
                    content_rowid='rowid'
                );
                CREATE TRIGGER catalog_ai AFTER INSERT ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(rowid, id, name, fullName, description, tap)
                    VALUES (new.rowid, new.id, new.name, new.fullName, new.description, new.tap);
                END;
                CREATE TRIGGER catalog_ad AFTER DELETE ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(catalog_fts, rowid, id, name, fullName, description, tap)
                    VALUES ('delete', old.rowid, old.id, old.name, old.fullName, old.description, old.tap);
                END;
                CREATE TRIGGER catalog_au AFTER UPDATE ON catalog_entries BEGIN
                    INSERT INTO catalog_fts(catalog_fts, rowid, id, name, fullName, description, tap)
                    VALUES ('delete', old.rowid, old.id, old.name, old.fullName, old.description, old.tap);
                    INSERT INTO catalog_fts(rowid, id, name, fullName, description, tap)
                    VALUES (new.rowid, new.id, new.name, new.fullName, new.description, new.tap);
                END;
                """)
        }
        try migrator.migrate(dbQueue)
    }

    func count() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM catalog_entries") ?? 0
        }
    }

    func replaceAll(_ entries: [CatalogEntry]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM catalog_entries")
            let stmt = try db.makeStatement(sql: """
                INSERT INTO catalog_entries (id, name, fullName, kind, version, tap, description, homepage)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """)
            for e in entries {
                try stmt.execute(arguments: [e.id, e.name, e.fullName, e.kind.rawValue, e.version, e.tap, e.description, e.homepage])
            }
        }
    }

    func search(query: String, kind: PackageKind? = nil, limit: Int = 80) throws -> CatalogSearchResult {
        let start = CFAbsoluteTimeGetCurrent()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let entries: [CatalogEntry] = try dbQueue.read { db in
            if trimmed.isEmpty {
                var sql = "SELECT id, name, fullName, kind, version, tap, description, homepage FROM catalog_entries"
                var args: StatementArguments = []
                if let kind {
                    sql += " WHERE kind = ?"
                    args += [kind.rawValue]
                }
                sql += " ORDER BY name ASC LIMIT ?"
                args += [limit]
                return try Row.fetchAll(db, sql: sql, arguments: args).map(Self.rowToEntry)
            }

            let tokens = trimmed
                .split(whereSeparator: { $0.isWhitespace })
                .map { token -> String in
                    let cleaned = token.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                    return cleaned.isEmpty ? "" : "\"\(cleaned)\"*"
                }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !tokens.isEmpty else { return [] }

            var sql = """
                SELECT c.id, c.name, c.fullName, c.kind, c.version, c.tap, c.description, c.homepage
                FROM catalog_fts f
                JOIN catalog_entries c ON c.rowid = f.rowid
                WHERE catalog_fts MATCH ?
                """
            var args: StatementArguments = [tokens]
            if let kind {
                sql += " AND c.kind = ?"
                args += [kind.rawValue]
            }
            sql += " ORDER BY bm25(catalog_fts, 0.0, 10.0, 6.0, 2.0, 1.0) LIMIT ?"
            args += [limit]

            return try Row.fetchAll(db, sql: sql, arguments: args).map(Self.rowToEntry)
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        return CatalogSearchResult(entries: entries, elapsedMs: elapsed)
    }

    private static func rowToEntry(_ row: Row) -> CatalogEntry {
        CatalogEntry(
            id: row["id"],
            name: row["name"],
            fullName: row["fullName"],
            kind: PackageKind(rawValue: row["kind"]) ?? .formula,
            version: row["version"],
            tap: row["tap"],
            description: row["description"],
            homepage: row["homepage"]
        )
    }

    /// Syncs from Homebrew's official JSON API (`formulae.brew.sh`), falling back to local cache names if offline.
    func syncCatalog() async throws -> Int {
        do {
            async let formulaData = fetchData(from: "https://formulae.brew.sh/api/formula.json")
            async let caskData = fetchData(from: "https://formulae.brew.sh/api/cask.json")
            let (fData, cData) = try await (formulaData, caskData)

            let formulae = try JSONDecoder().decode([RemoteFormula].self, from: fData)
            let casks = try JSONDecoder().decode([RemoteCask].self, from: cData)

            var all: [CatalogEntry] = []
            all.reserveCapacity(formulae.count + casks.count)

            for f in formulae {
                all.append(
                    CatalogEntry(
                        id: "formula:\(f.name)",
                        name: f.name,
                        fullName: f.fullName,
                        kind: .formula,
                        version: f.versions.stable ?? "latest",
                        tap: f.tap,
                        description: f.desc ?? "",
                        homepage: f.homepage ?? ""
                    )
                )
            }
            for c in casks {
                all.append(
                    CatalogEntry(
                        id: "cask:\(c.token)",
                        name: c.token,
                        fullName: c.fullToken,
                        kind: .cask,
                        version: c.version,
                        tap: c.tap,
                        description: c.desc ?? c.name.first ?? "",
                        homepage: c.homepage ?? ""
                    )
                )
            }

            try replaceAll(all)
            return all.count
        } catch {
            // Offline fallback: index local Homebrew cache name lists if present.
            let cacheEntries = loadLocalCacheNames()
            if !cacheEntries.isEmpty {
                try replaceAll(cacheEntries)
                return cacheEntries.count
            }
            throw error
        }
    }

    private func fetchData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private func loadLocalCacheNames() -> [CatalogEntry] {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return []
        }
        let apiDir = caches.appendingPathComponent("Homebrew/api", isDirectory: true)
        var entries: [CatalogEntry] = []

        if let fText = try? String(contentsOf: apiDir.appendingPathComponent("formula_names.txt"), encoding: .utf8) {
            for line in fText.split(whereSeparator: \.isNewline) {
                let name = String(line)
                entries.append(
                    CatalogEntry(
                        id: "formula:\(name)", name: name, fullName: name,
                        kind: .formula, version: "—", tap: "homebrew/core",
                        description: "Cached formula (sync online for metadata)", homepage: ""
                    )
                )
            }
        }
        if let cText = try? String(contentsOf: apiDir.appendingPathComponent("cask_names.txt"), encoding: .utf8) {
            for line in cText.split(whereSeparator: \.isNewline) {
                let name = String(line)
                entries.append(
                    CatalogEntry(
                        id: "cask:\(name)", name: name, fullName: name,
                        kind: .cask, version: "—", tap: "homebrew/cask",
                        description: "Cached cask (sync online for metadata)", homepage: ""
                    )
                )
            }
        }
        return entries
    }
}

private struct RemoteFormula: Decodable {
    struct Versions: Decodable { let stable: String? }
    let name: String
    let fullName: String
    let tap: String
    let desc: String?
    let homepage: String?
    let versions: Versions
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case tap, desc, homepage, versions
    }
}

private struct RemoteCask: Decodable {
    let token: String
    let fullToken: String
    let name: [String]
    let tap: String
    let desc: String?
    let homepage: String?
    let version: String
    enum CodingKeys: String, CodingKey {
        case token
        case fullToken = "full_token"
        case name, tap, desc, homepage, version
    }
}
