import Foundation

struct MetadataEncoder {
    static func encode<T: Codable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw SearchError.metadataEncodingFailed(NSError(domain: "SwiftFTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 data"]))
        }
        return string
    }
}

struct MetadataDecoder {
    static func decode<T: Codable>(_ type: T.Type, from string: String?) throws -> T? {
        guard let string else { return nil }
        
        guard let data = string.data(using: .utf8) else {
             throw SearchError.metadataDecodingFailed(NSError(domain: "SwiftFTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 string"]))
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SearchError.metadataDecodingFailed(error)
        }
    }
}
