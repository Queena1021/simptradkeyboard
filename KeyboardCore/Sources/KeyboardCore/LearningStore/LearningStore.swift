import Foundation
import SQLite3

public final class LearningStore {
    public struct Entry: Equatable {
        public let code: String
        public let candidate: String
        public let count: Int

        public init(code: String, candidate: String, count: Int) {
            self.code = code
            self.candidate = candidate
            self.count = count
        }
    }

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "LearningStore.serial")

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK else {
            if let h = handle { sqlite3_close(h) }
            throw NSError(domain: "LearningStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "sqlite3_open failed"])
        }
        self.db = handle

        let sql = """
        CREATE TABLE IF NOT EXISTS selections (
            code TEXT NOT NULL,
            candidate TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            last_used INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (code, candidate)
        );
        """
        try exec(sql)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public func recordSelection(code: String, candidate: String) {
        queue.sync {
            let sql = """
            INSERT INTO selections(code, candidate, count, last_used)
            VALUES(?, ?, 1, ?)
            ON CONFLICT(code, candidate)
            DO UPDATE SET count = count + 1, last_used = excluded.last_used;
            """
            let now = Int64(Date().timeIntervalSince1970)
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, code, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, candidate, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int64(stmt, 3, now)
            _ = sqlite3_step(stmt)
        }
    }

    public func frequencyBoost(code: String, candidate: String) -> Int {
        queue.sync {
            let sql = "SELECT count FROM selections WHERE code = ? AND candidate = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, code, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, candidate, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int64(stmt, 0))
            }
            return 0
        }
    }

    public func reset() {
        queue.sync { try? exec("DELETE FROM selections;") }
    }

    public func allEntries() -> [Entry] {
        queue.sync {
            var out: [Entry] = []
            let sql = "SELECT code, candidate, count FROM selections ORDER BY count DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let code = String(cString: sqlite3_column_text(stmt, 0))
                let cand = String(cString: sqlite3_column_text(stmt, 1))
                let cnt = Int(sqlite3_column_int64(stmt, 2))
                out.append(Entry(code: code, candidate: cand, count: cnt))
            }
            return out
        }
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw NSError(domain: "LearningStore", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}
