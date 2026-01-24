import Foundation
import SQLite3

/// Represents the FTS search engine.
public final class SearchEngine: @unchecked Sendable {
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let databaseQueue: FTSDatabaseQueue
    public var snippetParameters: FTSSnippetParameters?
    
    public init(databaseQueue: FTSDatabaseQueue, snippetParams: FTSSnippetParameters? = nil) {
        self.databaseQueue = databaseQueue
        self.snippetParameters = snippetParams
    }
    
    /// Searches the index.
    /// - Parameters:
    ///   - query: The search query.
    ///   - itemType: Optional document type to filter by.
    ///   - offset: Pagination offset.
    ///   - limit: Pagination limit. Defaults to 100.
    /// - Returns: An array of items matching the query.
    public func search<M: Codable & Sendable>(query: String, itemType: FTSItemType? = nil, offset: Int = 0, limit: Int = 100) async throws -> [FTSItem<M>] {
        try await search(query: query, itemType: itemType, offset: offset, limit: limit) { item in
            FTSItem(id: item.id, text: item.text, type: item.type, metadata: try item.metadata())
        }
    }
    
    /// Searches the index with a custom factory to create result objects.
    /// - Parameters:
    ///   - query: The search query. Defaults to AND query. Use `FTSQueryBuilder` for other query types.
    ///   - itemType: Optional document type to filter by.
    ///   - offset: Pagination offset.
    ///   - limit: Pagination limit. Defaults to 100.
    ///   - factory: A closure that creates a custom search result from the `FTSFactoryItem`.
    /// - Returns: An array of items matching the query.
    public func search<R: Sendable>(
        query: String,
        itemType: FTSItemType? = nil,
        offset: Int = 0,
        limit: Int = 100,
        factory: @escaping @Sendable (FTSFactoryItem) throws -> R
    ) async throws -> [R] {
        guard FTSQueryBuilder.isValid(query) else {
             return []
        }
        
        let rankFunctionName = databaseQueue.rankFunctionName
        let snippetParams = snippetParameters
        let transient = SQLITE_TRANSIENT
        
        return try await databaseQueue.execute { db in
            var selectSql = "SELECT l.id, l.content, l.type, l.metadata"
            if snippetParams != nil {
                selectSql += ", snippet(\(FTS5Setup.tableName), -1, ?, ?, ?, ?)"
            }
            
            var sql = """
            \(selectSql)
            FROM fts_lookup l
            JOIN \(FTS5Setup.tableName) f ON l.rowid = f.rowid
            WHERE f.content MATCH ?
            """
            
            if itemType != nil {
                sql += " AND l.type = ?"
            }
            
            if let rankFunctionName {
                sql += " ORDER BY \(rankFunctionName)(rank, l.priority, l.type) LIMIT ? OFFSET ?;"
            } else {
                sql += " ORDER BY -l.priority, rank LIMIT ? OFFSET ?;"
            }
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                throw SearchError.databaseError("Failed to prepare search statement")
            }
            defer { sqlite3_finalize(stmt) }
            
            // Bind query
            var argIndex: Int32 = 1
            if let snippetParams {
                sqlite3_bind_text(stmt, argIndex, (snippetParams.startMatch as NSString).utf8String, -1, transient)
                argIndex += 1
                sqlite3_bind_text(stmt, argIndex, (snippetParams.endMatch as NSString).utf8String, -1, transient)
                argIndex += 1
                sqlite3_bind_text(stmt, argIndex, (snippetParams.ellipsis as NSString).utf8String, -1, transient)
                argIndex += 1
                sqlite3_bind_int(stmt, argIndex, Int32(snippetParams.tokenCount))
                argIndex += 1
            }
            
            sqlite3_bind_text(stmt, argIndex, (query as NSString).utf8String, -1, transient)
            argIndex += 1
            
            // filter by item type, if present
            if let itemType {
                 sqlite3_bind_int(stmt, argIndex, Int32(itemType))
                 argIndex += 1
            }
            
            sqlite3_bind_int(stmt, argIndex, Int32(limit))
            argIndex += 1
            sqlite3_bind_int(stmt, argIndex, Int32(offset))
            
            var results: [R] = []
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idPtr = sqlite3_column_text(stmt, 0)
                let contentPtr = sqlite3_column_text(stmt, 1)
                let itemType = sqlite3_column_int(stmt, 2)
                let metadataPtr = sqlite3_column_text(stmt, 3)
                
                guard let idPtr, let contentPtr else {
                    continue
                }
                
                let id = String(cString: idPtr)
                let content = String(cString: contentPtr)
                var metadataStr: String? = nil
                
                // metadata is optional
                if let metadataPtr {
                    metadataStr = String(cString: metadataPtr)
                }
                
                // snippet is optional
                var snippet: String?
                if snippetParams != nil, let snippetPtr = sqlite3_column_text(stmt, 4) {
                    snippet = String(cString: snippetPtr)
                }
                
                // pass info to the factory handler
                let item = try factory(FTSFactoryItem(id: id, text: content, type: itemType, metadata: metadataStr, snippet: snippet))
                results.append(item)
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

