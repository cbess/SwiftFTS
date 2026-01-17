import Foundation
import SQLite3

internal struct FTS5Setup {
    /// FTS table name
    static let tableName = "swift_fts_index"
    
    /// Setup the indexer database tables
    static func setup(db: OpaquePointer) throws {
        // 1. create external lookup table
        let lookupSql = """
        CREATE TABLE IF NOT EXISTS fts_lookup(
            rowid INTEGER PRIMARY KEY AUTOINCREMENT,
            id TEXT NOT NULL UNIQUE,
            content TEXT,
            type INTEGER,
            metadata TEXT
        );
        """
        try exec(db, sql: lookupSql, errorMessage: "Failed to create lookup table")
        
        // 2. create indexes for fast lookup
        try exec(db, sql: "CREATE INDEX IF NOT EXISTS idx_fts_lookup_id ON fts_lookup(id);", errorMessage: "Failed to create id index")
        try exec(db, sql: "CREATE INDEX IF NOT EXISTS idx_fts_lookup_type ON fts_lookup(type);", errorMessage: "Failed to create type index")

        // 3. create fts5 virtual table connecting to external table
        let ftsSql = """
        CREATE VIRTUAL TABLE IF NOT EXISTS \(tableName) USING fts5(
            id, 
            content, 
            type UNINDEXED, 
            metadata UNINDEXED, 
            content='fts_lookup', 
            content_rowid='rowid', 
            tokenize='porter'
        );
        """
        try exec(db, sql: ftsSql, errorMessage: "Failed to create FTS5 table")
        
        // 4. create triggers to keep fts index in sync
        // trigger: after insert
        let triggerInsert = """
        CREATE TRIGGER IF NOT EXISTS fts_lookup_ai AFTER INSERT ON fts_lookup BEGIN
            INSERT INTO \(tableName)(rowid, id, content, type, metadata) VALUES (new.rowid, new.id, new.content, new.type, new.metadata);
        END;
        """
        try exec(db, sql: triggerInsert, errorMessage: "Failed to create insert trigger")
        
        // trigger: after delete
        let triggerDelete = """
        CREATE TRIGGER IF NOT EXISTS fts_lookup_ad AFTER DELETE ON fts_lookup BEGIN
            INSERT INTO \(tableName)(\(tableName), rowid, id, content, type, metadata) VALUES('delete', old.rowid, old.id, old.content, old.type, old.metadata);
        END;
        """
        try exec(db, sql: triggerDelete, errorMessage: "Failed to create delete trigger")
        
        // trigger: after update
        let triggerUpdate = """
        CREATE TRIGGER IF NOT EXISTS fts_lookup_au AFTER UPDATE ON fts_lookup BEGIN
            INSERT INTO \(tableName)(\(tableName), rowid, id, content, type, metadata) VALUES('delete', old.rowid, old.id, old.content, old.type, old.metadata);
            INSERT INTO \(tableName)(rowid, id, content, type, metadata) VALUES (new.rowid, new.id, new.content, new.type, new.metadata);
        END;
        """
        try exec(db, sql: triggerUpdate, errorMessage: "Failed to create update trigger")
    }
    
    private static func exec(_ db: OpaquePointer, sql: String, errorMessage: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw SearchError.databaseError("\(errorMessage): \(msg)")
        }
    }
}

