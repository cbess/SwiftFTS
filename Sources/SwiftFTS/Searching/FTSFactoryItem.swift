//
//  FTSFactoryItem.swift
//  SwiftFTS
//
//  Created by C. Bess on 1/18/26.
//

/// Represents the factory item used to construct the final search result.
public struct FTSFactoryItem: Sendable {
    public let id: String
    public let text: String
    public let type: FTSItemType
    /// The metadata JSON string.
    public let metadataString: String?
    /// The snippet text with match highlighting.
    public let snippet: String?
    
    public init(id: String, text: String, type: FTSItemType = FTSItemTypeUnspecified, metadata: String? = nil, snippet: String? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.metadataString = metadata
        self.snippet = snippet
    }
    
    /// Decodes the metadata JSON string into the expected object or nil.
    public func metadata<T: Codable>() throws -> T? {
        return try MetadataDecoder.decode(T.self, from: metadataString)
    }
}
