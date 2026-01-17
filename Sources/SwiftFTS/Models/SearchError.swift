import Foundation

public enum SearchError: Error, LocalizedError {
    case databaseError(String)
    case indexingFailed(String)
    case searchFailed(String)
    case invalidQuery(String)
    case metadataEncodingFailed(Error)
    case metadataDecodingFailed(Error)
    case databaseNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .databaseError(let message): 
            return "Database error: \(message)"
        case .indexingFailed(let message): 
            return "Indexing failed: \(message)"
        case .searchFailed(let message): 
            return "Search failed: \(message)"
        case .invalidQuery(let message): 
            return "Invalid query: \(message)"
        case .metadataEncodingFailed(let error): 
            return "Metadata encoding failed: \(error.localizedDescription)"
        case .metadataDecodingFailed(let error): 
            return "Metadata decoding failed: \(error.localizedDescription)"
        case .databaseNotInitialized: 
            return "Database not initialized"
        }
    }
}
