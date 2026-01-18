import Foundation

/// A type alias for the item type identifier.
public typealias FTSItemType = Int32

/// The default unspecified FTS item type.
public let FTSItemTypeUnspecified: FTSItemType = -1

/// A type representing an item that can be indexed and searched.
public protocol FullTextSearchable<Metadata>: Sendable {
    associatedtype Metadata: Codable & Sendable

    /// Unique identifier for the item.
    var indexItemID: String { get }
    
    /// The text content to be indexed for full-text search.
    var indexText: String { get }
    
    /// The type or category of the item.
    var indexItemType: FTSItemType { get }
    
    /// Additional metadata associated with the item.
    var indexMetadata: Metadata? { get }
    
    /// Indicates if the item can be indexed.
    var canIndex: Bool { get }
    
    /// Called before the item is indexed.
    func willIndex()
    
    /// Called after the item has been indexed.
    func didIndex()
}

public extension FullTextSearchable {
    var canIndex: Bool { true }
    func willIndex() {}
    func didIndex() {}
}
