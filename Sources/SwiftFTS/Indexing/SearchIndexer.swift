import Foundation
import SQLite3

private let SQLInBatchSize = 900

public final class SearchIndexer: @unchecked Sendable {
    private let databaseQueue: FTSDatabaseQueue
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    public init(databaseQueue: FTSDatabaseQueue) async throws {
        self.databaseQueue = databaseQueue
        try await databaseQueue.execute { db in
            try FTS5Setup.setup(db: db)
        }
    }

    /// Adds multiple items to the index.
    public func addItems<T: FullTextSearchable>(_ items: [T]) async throws {
        guard !items.isEmpty else { return }
        
        let transient = self.SQLITE_TRANSIENT
        // use UPSERT (ON CONFLICT DO UPDATE) to handle updates
        // this fires the UPDATE trigger, preserving the rowid and correctly updating the FTS index
        let sql = """
                INSERT INTO fts_lookup (id, content, type, metadata) VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    content=excluded.content,
                    type=excluded.type,
                    metadata=excluded.metadata;
                """
        
        try await databaseQueue.execute { db in
            try self.performTransaction(db: db) {
                var stmt: OpaquePointer?
                
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                    throw SearchError.databaseError("Failed to prepare insert statement")
                }
                defer { sqlite3_finalize(stmt) }
                
                for item in items {
                    // skip, if cannot index
                    guard item.canIndex else { continue }
                    
                    item.willIndex()
                    
                    let id = item.indexItemID
                    let text = item.indexText
                    let type = item.indexItemType
                    let metadata = try MetadataEncoder.encode(item.indexMetadata)
                    
                    sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, transient)
                    sqlite3_bind_text(stmt, 2, (text as NSString).utf8String, -1, transient)
                    sqlite3_bind_int(stmt, 3, Int32(type))
                    
                    // metadata is optional
                    if let metadataStr = (metadata as? NSString)?.utf8String {
                        sqlite3_bind_text(stmt, 4, metadataStr, -1, transient)
                    } else {
                        sqlite3_bind_null(stmt, 4)
                    }
                    
                    if sqlite3_step(stmt) != SQLITE_DONE {
                        throw SearchError.indexerFailed("Failed to insert document: \(id)")
                    }
                    
                    sqlite3_reset(stmt)
                    item.didIndex()
                }
            }
        }
    }
    
    /// Updates a single item.
    public func updateItem<T: FullTextSearchable>(_ item: T) async throws {
        // since we use UPSERT in addItems, we can just call that
        try await addItems([item])
    }
    
    /// Removes the item with the specified id.
    public func removeItem(id: String) async throws {
        let transient = self.SQLITE_TRANSIENT
        
        try await databaseQueue.execute { db in
            try self.performTransaction(db: db) {
                let sql = "DELETE FROM fts_lookup WHERE id = ?;"
                var stmt: OpaquePointer?
                
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                    throw SearchError.databaseError("Failed to prepare delete statement")
                }
                defer { sqlite3_finalize(stmt) }
                
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, transient)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    throw SearchError.indexerFailed("Failed to delete document: \(id)")
                }
            }
        }
    }
    
    /// Removes multiple items with the specified ids.
    public func removeItems(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        
        let transient = self.SQLITE_TRANSIENT
        
        // Process in batches to stay within SQLite parameter limits
        for batchStartIndex in stride(from: 0, to: ids.count, by: SQLInBatchSize) {
            let batchEndIndex = min(batchStartIndex + SQLInBatchSize, ids.count)
            let batch = Array(ids[batchStartIndex..<batchEndIndex])
            
            try await databaseQueue.execute { db in
                try self.performTransaction(db: db) {
                    // delete from lookup table; a trigger handles the FTS index
                    // Build placeholders for IN clause: (?, ?, ?)
                    let placeholders = batch.map { _ in "?" }.joined(separator: ", ")
                    let sql = "DELETE FROM fts_lookup WHERE id IN (\(placeholders));"
                    var stmt: OpaquePointer?
                    
                    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                        throw SearchError.databaseError("Failed to prepare delete statement")
                    }
                    defer { sqlite3_finalize(stmt) }
                    
                    // Bind all the IDs in this batch
                    for (index, id) in batch.enumerated() {
                        sqlite3_bind_text(stmt, Int32(index + 1), (id as NSString).utf8String, -1, transient)
                    }
                    
                    if sqlite3_step(stmt) != SQLITE_DONE {
                        throw SearchError.indexerFailed("Failed to delete documents in batch range: (\(batchStartIndex)..<\(batchEndIndex))")
                    }
                }
            }
        }
    }

    /// Reindex database to delete and recreate indexes from scratch. May take a while to complete.
    public func reindex() async throws {
        try await databaseQueue.execute { db in
            let sql = "INSERT INTO \(FTS5Setup.tableName)(\(FTS5Setup.tableName)) VALUES('rebuild');"
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                 throw SearchError.databaseError("Failed to rebuild index")
            }
        }
    }
    
    /// Optimizes the database by updating stats for the query planner. Executes quickly.
    public func optimize() async throws {
        try await databaseQueue.execute { db in
             let sql = "INSERT INTO \(FTS5Setup.tableName)(\(FTS5Setup.tableName)) VALUES('optimize');"
             if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                 throw SearchError.databaseError("Failed to optimize index")
             }
        }
    }
    
    /// Returns the total count of items in the FTS index.
    public func count() async throws -> Int {
        try await databaseQueue.execute { db in
             let sql = "SELECT COUNT(*) FROM \(FTS5Setup.tableName);"
             var stmt: OpaquePointer?
             
             if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                 throw SearchError.databaseError("Failed to prepare count statement")
             }
             defer { sqlite3_finalize(stmt) }
             
             if sqlite3_step(stmt) == SQLITE_ROW {
                 return Int(sqlite3_column_int(stmt, 0))
             }
             
             return 0
        }
    }
    
    private func performTransaction(db: OpaquePointer, block: () throws -> Void) throws {
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        do {
            try block()
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        } catch {
            sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }
}

// MARK: - Deprecated Completion Handlers

public extension SearchIndexer {
    @available(*, deprecated, message: "Use async/await variant instead")
    func addItems<T: FullTextSearchable>(_ items: [T], completion: @escaping @Sendable (Error?) -> Void) {
        Task {
            do {
                try await addItems(items)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    @available(*, deprecated, message: "Use async/await variant instead")
    func updateItem<T: FullTextSearchable>(_ item: T, completion: @escaping @Sendable (Error?) -> Void) {
        Task {
            do {
                try await updateItem(item)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    @available(*, deprecated, message: "Use async/await variant instead")
    func removeItem(id: String, completion: @escaping @Sendable (Error?) -> Void) {
        Task {
            do {
                try await removeItem(id: id)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    @available(*, deprecated, message: "Use async/await variant instead")
    func removeItems(ids: [String], completion: @escaping @Sendable (Error?) -> Void) {
        Task {
            do {
                try await removeItems(ids: ids)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}
