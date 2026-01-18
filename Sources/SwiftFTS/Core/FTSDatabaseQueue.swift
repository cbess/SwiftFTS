import Foundation
import SQLite3

/// The in-memory db path name.
public let InMemoryDatabasePathName: String = ":memory:"

/// The default FTS database Sqlite open flags, for read, write and create operations.
public let FTSDBDefaultOpenFlags: Int32 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE

/// Represents the FTS database queue which handles all raw db operations.
public class FTSDatabaseQueue: @unchecked Sendable {
    public static let inMemoryPath: String = InMemoryDatabasePathName
    private let queue = DispatchQueue(label: "com.swiftfts.database", qos: .userInitiated)
    private var db: OpaquePointer?
    private let path: String
    
    /// Returns a new in-memory database queue.
    public class func makeInMemory() async throws -> FTSDatabaseQueue {
        return try await FTSDatabaseQueue(path: inMemoryPath)
    }
    
    /// Returns a new readonly database queue.
    public class func makeReadonly(path: String) async throws -> FTSDatabaseQueue {
        return try await FTSDatabaseQueue(path: path, flags: SQLITE_OPEN_READONLY)
    }
    
    /// Initializes a db queue and opens the db for read, write and create operations.
    public convenience init(path: String) async throws {
        try await self.init(path: path, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
    }
    
    /// Initializes a db queue and opens the db.
    public init(path: String, flags: Int32 = FTSDBDefaultOpenFlags) async throws {
        self.path = path
        try await open(flags: flags)
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    /// Opens the database using the specified flags.
    public func open(flags: Int32) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if self.db != nil { 
                    continuation.resume()
                    return 
                }
                
                if sqlite3_open_v2(self.path, &self.db, flags, nil) != SQLITE_OK {
                    let errorMsg = String(cString: sqlite3_errmsg(self.db))
                    continuation.resume(throwing: SearchError.databaseError("Failed to open database: \(errorMsg)"))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Closes the connection to the database, if needed.
    public func close() async {
        await withCheckedContinuation { continuation in
            queue.async {
                if let db = self.db {
                    sqlite3_close(db)
                    self.db = nil
                }
                continuation.resume()
            }
        }
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
