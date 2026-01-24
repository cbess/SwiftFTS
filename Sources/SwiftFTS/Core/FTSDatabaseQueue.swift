import Foundation
import SQLite3

/// The in-memory db path name.
public let InMemoryDatabasePathName: String = ":memory:"

/// The default FTS database Sqlite open flags, for read, write and create operations.
public let FTSDBDefaultOpenFlags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE

fileprivate let FTSCustomRankArgCount: Int32 = 3

/// Represents the FTS database queue which handles all raw db operations.
public class FTSDatabaseQueue: @unchecked Sendable {
    public static let inMemoryPath: String = InMemoryDatabasePathName
    private let queue = DispatchQueue(label: "com.swiftfts.database", qos: .userInitiated)
    internal private(set) var db: OpaquePointer?
    private let path: String
    
    /// The name of the custom rank function, if any.
    public private(set) var rankFunctionName: String?
    
    /// Returns a new in-memory database queue.
    public class func makeInMemory() throws -> FTSDatabaseQueue {
        return try FTSDatabaseQueue(path: inMemoryPath)
    }
    
    /// Returns a new readonly database queue.
    public class func makeReadonly(path: String) throws -> FTSDatabaseQueue {
        return try FTSDatabaseQueue(path: path, flags: SQLITE_OPEN_READONLY)
    }
    
    /// Initializes a db queue and opens the db.
    public init(path: String, flags: Int32 = FTSDBDefaultOpenFlags) throws {
        self.path = path
        try open(flags: flags)
    }
    
    deinit {
        close()
    }
    
    /// Opens the database using the specified flags.
    public func open(flags: Int32) throws {
        guard db == nil else {
            return
        }
        
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            _ = sqlite3_close(db)
            throw SearchError.databaseError("Failed to open database: \(errorMsg)")
        }
        
        if let db = db {
            // enable more detailed error information
            sqlite3_extended_result_codes(db, 1)
        }
    }
    
    /// Closes the connection to the database, if needed.
    public func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    /// Registers the custom rank function used in search queries.
    /// - Parameters:
    ///   - name: The name of the function to use in SQL.
    ///   - block: The custom rank function implementation.
    ///     The closure receives:
    ///     - `context`: OpaquePointer? - The SQLite context
    ///     - `argc`: Int32 - Argument count (will always be 3)
    ///     - `argv`: UnsafeMutablePointer<OpaquePointer?>? - Arguments array
    ///       - `argv[0]`: bm25 doc score (DOUBLE) - The rank. Smaller number, better match.
    ///       - `argv[1]`: priority (INTEGER) - FTS item priority.
    ///       - `argv[2]`: type (INTEGER) - FTS item type.
    public func registerRankFunction(name: String, block: @escaping @convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void) throws {
        guard let db = self.db else { return }
        
        // store func name
        rankFunctionName = name
        
        let result = sqlite3_create_function(
            db,
            name,
            // nArg (bm25|rank, priority, type)
            FTSCustomRankArgCount,
            SQLITE_UTF8,
            nil,
            block,
            nil,
            nil
        )
        
        if result != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SearchError.databaseError("Failed to register custom rank function: \(msg)")
        }
    }
    
    /// Unregisters the custom rank function
    public func unregisterRankFunction() throws {
        guard rankFunctionName != nil, let db = self.db else {
            return
        }
        
        let result = sqlite3_create_function(
            db,
            rankFunctionName,
            FTSCustomRankArgCount,
            SQLITE_UTF8,
            nil,
            nil,
            nil,
            nil
        )
        
        if result != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw SearchError.databaseError("Failed to unregister custom rank function: \(msg)")
        }
        
        rankFunctionName = nil
    }
    
    /// Provides the execution block for database operations, passing it the sqlite db pointer.
    public func execute<T: Sendable>(_ block: @escaping @Sendable (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let db = self.db else {
                    continuation.resume(throwing: SearchError.databaseNotInitialized)
                    return
                }
                
                do {
                    let result = try block(db)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Executes raw SQL statements without returing any results.
    public func execute(sql: String) async throws {
        try await execute { db in
            var errorMessage: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
                let msg = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                throw SearchError.databaseError("Execute failed: \(msg)")
            }
        }
    }
}
