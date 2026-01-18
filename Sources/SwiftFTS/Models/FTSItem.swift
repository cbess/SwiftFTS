import Foundation

/// A convenient concrete implementation of `FullTextSearchable` for generic usage.
public struct FTSItem<Metadata: Codable & Sendable>: FullTextSearchable {
    public let indexItemID: String
    public let indexText: String
    public let indexItemType: FTSItemType
    public let indexMetadata: Metadata?
    
    public init(id: String, text: String, itemType: FTSItemType = FTSItemTypeUnspecified, metadata: Metadata? = nil) {
        self.indexItemID = id
        self.indexText = text
        self.indexItemType = itemType
        self.indexMetadata = metadata
    }
}

