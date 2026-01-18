import Foundation

/// Represents the FTS query builder helper operations.
public struct FTSQueryBuilder {
    /// Builds a phrase query (exact match for the sequence of words).
    public static func phraseQuery(_ phrase: String) -> String {
        // prevents needing to escape chars, since anything in quotes is a part of the terms
        let quoted = phrase.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(quoted)\""
    }
    
    /// Builds an OR query from the terms.
    public static func orQuery(_ terms: String...) -> String {
        return orQuery(terms)
    }
    
    /// Builds an OR query from multiple terms.
    public static func orQuery(_ terms: [String]) -> String {
        return terms
            .map { phraseQuery($0) }
            .joined(separator: " OR ")
    }
    
    /// Builds an AND query from the terms.
    public static func andQuery(_ terms: String...) -> String {
        return andQuery(terms)
    }
    
    /// Builds an AND query from multiple terms.
    public static func andQuery(_ terms: [String]) -> String {
        return terms
            .map { phraseQuery($0) }
            .joined(separator: " AND ")
    }
    
    /// Validates if a query string is likely safe/valid (basic check).
    public static func isValid(_ query: String) -> Bool {
        return !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
