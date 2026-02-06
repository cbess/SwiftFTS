import Foundation

/// A type alias for the item type identifier.
public typealias FTSItemType = Int32

/// The default unspecified FTS item type.
public let FTSItemTypeUnspecified: FTSItemType = 0

/// The default FTS item priority.
public let FTSItemDefaultPriority = 0

/// A convenient concrete implementation of `FullTextSearchable` for generic usage.
public struct FTSItem<Metadata: Codable & Sendable>: FullTextSearchable {
    public let indexItemID: String
    public let indexText: String
    public let indexItemType: FTSItemType
    public let indexMetadata: Metadata?
    public let indexPriority: Int
    
    public init(id: String, text: String, type: FTSItemType = FTSItemTypeUnspecified, metadata: Metadata? = nil, priority: Int = FTSItemDefaultPriority) {
        self.indexItemID = id
        self.indexText = text
        self.indexItemType = type
        self.indexMetadata = metadata
        self.indexPriority = priority
    }
}

/// A simple metadata container for use with `FTSItem` or basic usage.
public struct FTSItemMetadata: Codable, Sendable {
    /// A string hash map
    public var map: [String: String]?
    /// A string array
    public var array: [String]?
}
