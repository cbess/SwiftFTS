import Foundation
import SQLite3

/// A wrapper around FTS components for easier management.
public final class SwiftFTS: @unchecked Sendable {
    /// The database queue used for operations.
    public let databaseQueue: FTSDatabaseQueue
    
    /// The indexer used to index documents.
    public let indexer: SearchIndexer
    
    /// The search engine used to search documents.
    public let searchEngine: SearchEngine
    
    /// A convenience factory to make an in-memory FTS
    public static func makeInMemory() throws -> SwiftFTS {
        let queue = try FTSDatabaseQueue.makeInMemory()
        return try SwiftFTS(databaseQueue: queue)
    }
    
    /// Initializes a new SwiftFTS instance.
    /// - Parameter databaseQueue: The database queue to use.
    public init(databaseQueue: FTSDatabaseQueue) throws {
        self.databaseQueue = databaseQueue
        self.indexer = try SearchIndexer(databaseQueue: databaseQueue)
        self.searchEngine = SearchEngine(databaseQueue: databaseQueue)
    }
    
    /// Registers a custom rank function for use in search queries to sort results.
    ///
    /// The function will be called for each potential search result in `ORDER BY`.
    /// It should extract the arguments and use `sqlite3_result_double` (or similar) to return a sortable numeric value.
    ///
    /// - Parameters:
    ///   - name: The name of the function to be used in SQL queries.
    ///   - block: A closure that implements the custom rank logic.
    ///     The closure receives:
    ///     - `context`: OpaquePointer? - The SQLite context
    ///     - `argc`: Int32 - Argument count (will be 3)
    ///     - `argv`: UnsafeMutablePointer<OpaquePointer?>? - Arguments array
    ///       - `argv[0]`: doc rank (DOUBLE) - The smaller the number the better the match.
    ///       - `argv[1]`: fts item priority (INTEGER)
    ///       - `argv[2]`: fts item type (INTEGER)
    public func registerRankFunction(name: String, block: @escaping @convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void) throws {
        try databaseQueue.registerRankFunction(name: name, block: block)
    }
    
    /// Closes the database
    public func close() {
        databaseQueue.close()
    }
}
