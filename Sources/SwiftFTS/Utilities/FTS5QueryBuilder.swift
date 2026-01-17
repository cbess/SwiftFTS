import Foundation

public struct FTS5QueryBuilder {
    /// Escapes special characters in an FTS5 query to prevent syntax errors or injection.
    /// FTS5 special characters include: " * : ^
    public static func escapeSpecialCharacters(_ query: String) -> String {
        // Characters: " * : ^
        // Escape check code removed as unused for now, just simplifying logic.
        
        let escaped = query.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    /// Builds a phrase query (exact match for the sequence of words).
    public static func buildPhraseQuery(_ phrase: String) -> String {
        return escapeSpecialCharacters(phrase)
    }
    
    /// Validates if a query string is likely safe/valid (basic check).
    public static func validateQuery(_ query: String) -> Bool {
        return !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
