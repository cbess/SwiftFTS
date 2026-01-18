import Foundation
import SQLite3

public final class SearchEngine: @unchecked Sendable {
    private let databaseQueue: FTSDatabaseQueue
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    public init(databaseQueue: FTSDatabaseQueue) {
        self.databaseQueue = databaseQueue
    }
    
    /// Searches the index.
    /// - Parameters:
    ///   - query: The search query.
    ///   - itemType: Optional document type to filter by.
    ///   - offset: Pagination offset.
    ///   - limit: Pagination limit. Defaults to 100.
    /// - Returns: An array of items matching the query.
    public func search<M: Codable & Sendable>(query: String, itemType: FTSItemType? = nil, offset: Int = 0, limit: Int = 100) async throws -> [any FullTextSearchable<M>] {
        // "Query validation ... via FTS5QueryBuilder" implies we call validation.
        if !FTS5QueryBuilder.validateQuery(query) {
             // But validation just checks not empty.
             return []
             // If query is empty, FTS match might match nothing or everything depending on query.
        }
        
        let transient = self.SQLITE_TRANSIENT
        return try await databaseQueue.execute { db in
            var sql = """
            SELECT l.id, l.content, l.type, l.metadata
            FROM fts_lookup l
            JOIN \(FTS5Setup.tableName) f ON l.rowid = f.rowid
            WHERE \(FTS5Setup.tableName) MATCH ?
            """
            
            if itemType != nil {
                sql += " AND l.type = ?"
            }
            
            sql += " ORDER BY rank LIMIT ? OFFSET ?;"
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                throw SearchError.databaseError("Failed to prepare search statement")
            }
            defer { sqlite3_finalize(stmt) }
            
            // Bind query
            // So we should expect the user to use QueryBuilder if they want complex queries, OR we blindly escape if we treat input as raw text.

            // the user is responsible for building a valid FTS5 query string using FTS5QueryBuilder for terms.
            
            sqlite3_bind_text(stmt, 1, (query as NSString).utf8String, -1, transient)
            
            var argIndex: Int32 = 2
            if let itemType {
                 sqlite3_bind_int(stmt, argIndex, Int32(itemType))
                 argIndex += 1
            }
            
            sqlite3_bind_int(stmt, argIndex, Int32(limit))
            argIndex += 1
            sqlite3_bind_int(stmt, argIndex, Int32(offset))
            
            var results: [FTSItem<M>] = []
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idPtr = sqlite3_column_text(stmt, 0)
                let contentPtr = sqlite3_column_text(stmt, 1)
                let typeVal = sqlite3_column_int(stmt, 2)
                let metadataPtr = sqlite3_column_text(stmt, 3)
                
                guard let idPtr, let contentPtr else {
                    continue
                }
                
                let id = String(cString: idPtr)
                let content = String(cString: contentPtr)
                let itemType = Int(typeVal)
                var metadata: M? = nil
                
                if let metadataPtr {
                    do {
                        metadata = try MetadataDecoder.decode(M.self, from: String(cString: metadataPtr))
                    } catch {
                        throw SearchError.metadataDecodingFailed(error)
                    }
                }
                
                let doc = FTSItem(id: id, text: content, itemType: itemType, metadata: metadata)
                results.append(doc)
            }
            
            return results
        }
    }
}

// MARK: - Deprecated

public extension SearchEngine {
    @available(*, deprecated, message: "Use async/await variant instead")
    func search<M: Codable & Sendable>(query: String, itemType: FTSItemType? = nil, offset: Int = 0, limit: Int = 100, completion: @escaping @Sendable ([any FullTextSearchable<M>]?, Error?) -> Void) {
        Task {
            do {
                let results: [any FullTextSearchable<M>] = try await search(query: query, itemType: itemType, offset: offset, limit: limit)
                DispatchQueue.main.async { completion(results, nil) }
            } catch {
                DispatchQueue.main.async { completion(nil, error) }
            }
        }
    }
}
