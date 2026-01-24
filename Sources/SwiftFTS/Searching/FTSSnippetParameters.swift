import Foundation

/// Represents FTS snippet parameters.
public struct FTSSnippetParameters: Sendable {
    /// The text to insert before a match. Defaults to `«`.
    public let startMatch: String
    
    /// The text to insert after a match. Defaults to `»`.
    public let endMatch: String
    
    /// The text to indicate that text has been omitted. Defaults to `…`.
    public let ellipsis: String
    
    /// The maximum number of tokens to include in the snippet. Defaults to 64 (~15 words).
    /// Note: SQLite uses tokens, not strictly words.
    public let tokenCount: Int
    
    /// - Parameters:
    ///   - startMatch: The text to insert before a match. Defaults to `«`.
    ///   - endMatch: The text to insert after a match. Defaults to `»`.
    ///   - ellipsis: The text to indicate that text has been omitted. Defaults to `…`.
    ///   - tokenCount: The maximum number of tokens to include in the snippet. Defaults to 30.
    public init(startMatch: String = "«", endMatch: String = "»", ellipsis: String = "…", tokenCount: Int = 30) {
        self.startMatch = startMatch
        self.endMatch = endMatch
        self.ellipsis = ellipsis
        self.tokenCount = tokenCount
    }
}
