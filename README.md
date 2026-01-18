# SwiftFTS

SwiftFTS is a Swift wrapper around SQLite FTS5 for fast and simple full-text search on iOS/macOS. Built with Swift Concurrency, it provides a modern async/await API for indexing and searching your content with powerful SQLite FTS5 features.

## Features

- 🚀 Modern async/await API
- 📦 Rich metadata support for indexed items
- ⚡️ Fast SQLite FTS5 engine (ranking, prefix queries, phrase matching)
- 🔒 Thread-safe `FTSDatabaseQueue`
- 🎯 Type-safe search results with generics
- 🛠 Query builder for complex searches (AND, OR, phrases)
- 📄 Pagination support
- 🔄 Update and remove operations
- 🎨 Custom result transformation with factory closures
- ✅ 100% test coverage
- 📦 No external dependencies

## Installation

### Swift Package Manager

Add the following to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/cbess/SwiftFTS.git", from: "0.5.0")
]
```

And include `SwiftFTS` in your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftFTS", package: "SwiftFTS")
        ]
    )
]
```

## Quick Start

```swift
import SwiftFTS

// Create an in-memory database
let dbQueue = try await FTSDatabaseQueue.makeInMemory()

// Or create a file-based database
// let dbQueue = try await FTSDatabaseQueue(path: "path/to/db.sqlite")

// Initialize indexer and search engine
let indexer = try await SearchIndexer(databaseQueue: dbQueue)
let engine = SearchEngine(databaseQueue: dbQueue)

// Add documents
struct Article: FullTextSearchable {
    let id: String
    let text: String
    
    var indexItemID: String { id }
    var indexText: String { text }
    var indexItemType: FTSItemType { FTSItemTypeUnspecified }
    var indexMetadata: String? { nil }
}

let article = Article(id: "one", text: "Soli Deo gloria")
try await indexer.addItems([article])

// Search
let results: [any FullTextSearchable<String?>] = try await engine.search(query: "gloria")
print(results.first?.indexText ?? "")
```

## Usage

### 1. Define Your Document Type

Adopt the `FullTextSearchable` protocol to make your types searchable (or inherit from `FTSItem`):

```swift
struct MyDocument: FullTextSearchable {
    // Define your metadata structure
    struct Metadata: Codable, Sendable {
        let author: String
        let year: Int
        let category: String
    }
    
    let id: String
    let content: String
    let type: FTSItemType
    let metadata: Metadata?
    
    // Conform to FullTextSearchable
    var indexItemID: String { id }
    var indexText: String { content }
    var indexItemType: FTSItemType { type }
    var indexMetadata: Metadata? { metadata }
}
```

**Optional metadata**: Your metadata can be optional (`Metadata?`) if not all documents have metadata.

### 2. Setup Database and Components

```swift
// Create database queue (thread-safe)
let dbQueue = try await FTSDatabaseQueue.makeInMemory()
// Or: let dbQueue = try await FTSDatabaseQueue(path: "/path/to/database.sqlite")

// Create indexer for adding/updating/removing documents
let indexer = try await SearchIndexer(databaseQueue: dbQueue)

// Create search engine for querying
let engine = SearchEngine(databaseQueue: dbQueue)
```

### 3. Index Your Documents

#### Adding Items

```swift
let doc1 = Document(
    id: "1",
    content: "Swift is a powerful programming language.",
    type: 1,
    metadata: Document.Metadata(author: "Apple", year: 2014, category: "Programming")
)

let doc2 = Document(
    id: "2",
    content: "Objective-C was the primary language for iOS.",
    type: 1,
    metadata: Document.Metadata(author: "NeXT", year: 1984, category: "Legacy")
)

// Add multiple documents at once
try await indexer.addItems([doc1, doc2])
```

#### Updating Items

```swift
let updatedDoc = Document(
    id: "1",
    content: "Swift is a powerful and modern programming language.",
    type: 1,
    metadata: Document.Metadata(author: "Apple", year: 2024, category: "Programming")
)

try await indexer.updateItem(updatedDoc)
```

#### Removing Items

```swift
// Remove a single item
try await indexer.removeItem(id: "1")

// Remove multiple items
try await indexer.removeItems(ids: ["1", "2", "3"])
```

#### Other Operations

```swift
// Get total count of indexed items
let count = try await indexer.count()

// Get total count of indexed items of a specific item type
let countType3 = try await indexer.count(type: 3)

// Optimize the database (reclaim space after deletions)
try await indexer.optimize()

// Rebuild the entire FTS index
try await indexer.reindex()
```

### 4. Search Your Documents

#### Basic Search

```swift
// Simple search (case-insensitive)
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(query: "Swift")

for result in results {
    print("ID: \(result.indexItemID)")
    print("Text: \(result.indexText)")
    print("Author: \(result.indexMetadata?.author ?? "Unknown")")
}
```

#### Search with Type Filter

```swift
// Search only documents of a specific type
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(
    query: "programming",
    itemType: 1
)
```

#### Pagination

```swift
// Get first page (10 results)
let page1: [any FullTextSearchable<Document.Metadata>] = try await engine.search(
    query: "Swift",
    offset: 0,
    limit: 10
)

// Get second page
let page2: [any FullTextSearchable<Document.Metadata>] = try await engine.search(
    query: "Swift",
    offset: 10,
    limit: 10
)
```

### 5. Advanced Query Building

Use `FTSQueryBuilder` for complex queries:

#### OR Queries

```swift
// Find documents matching ANY of the terms
let query = FTSQueryBuilder.orQuery("Swift", "Objective-C", "Python")
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(query: query)
```

#### AND Queries

```swift
// Find documents matching ALL of the terms
let query = FTSQueryBuilder.andQuery("Swift", "programming", "language")
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(query: query)
```

#### Phrase Queries

```swift
// Exact phrase matching
let query = FTSQueryBuilder.phraseQuery("powerful programming language")
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(query: query)
```

#### Validate Queries

```swift
let isValid = FTSQueryBuilder.isValid(userInput)
if isValid {
    let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(query: userInput)
}
```

### 6. Custom Result Transformation

Use factory closures to transform search results into your custom types:

```swift
// Transform FTSItem results into your Document type
let documents: [Document] = try await engine.search(query: "Swift", factory: { ftsItem in
    Document(
        id: ftsItem.id,
        content: ftsItem.text,
        type: ftsItem.type,
        metadata: try ftsItem.metadata()
    )
})

// Custom transformation with additional logic
struct EnrichedDocument {
    let id: String
    let text: String
    let isRecent: Bool
    let author: String?
}

let enriched: [EnrichedDocument] = try await engine.search(query: "Swift", factory: { ftsItem in
    let metadata: Document.Metadata? = try ftsItem.metadata()
    return EnrichedDocument(
        id: ftsItem.id,
        text: ftsItem.text,
        isRecent: (metadata?.year ?? 0) > 2020,
        author: metadata?.author
    )
})
```

## Advanced Features

### Document Type Categories

Use `FTSItemType` to categorize your documents:

```swift
let article = Document(id: "1", content: "...", type: 1, metadata: ...)  // Articles
let tutorial = Document(id: "2", content: "...", type: 2, metadata: ...) // Tutorials
let reference = Document(id: "3", content: "...", type: 3, metadata: ...) // Reference docs

// Search only tutorials
let results: [any FullTextSearchable<Document.Metadata>] = try await engine.search(
    query: "Swift",
    itemType: 2
)
```

### Optional Metadata Handling

Documents can have optional metadata:

```swift
struct Article: FullTextSearchable {
    let id: String
    let text: String
    let metadata: ArticleMetadata?  // Optional
    
    var indexItemID: String { id }
    var indexText: String { text }
    var indexItemType: FTSItemType { FTSItemTypeUnspecified }
    var indexMetadata: ArticleMetadata? { metadata }
}

// Some documents with metadata, some without
let withMeta = Article(id: "1", text: "...", metadata: ArticleMetadata(...))
let withoutMeta = Article(id: "2", text: "...", metadata: nil)

try await indexer.addItems([withMeta, withoutMeta])
```

### Lifecycle Hooks

Implement optional hooks to respond to indexing events:

```swift
struct Document: FullTextSearchable {
    // ... properties ...
    
    var canIndex: Bool {
        // Return false to skip indexing this document
        !content.isEmpty
    }
    
    func willIndex() {
        // Called before indexing
        print("About to index: \(id)")
    }
    
    func didIndex() {
        // Called after successful indexing
        print("Successfully indexed: \(id)")
    }
}
```

### Large Batch Operations

SwiftFTS automatically handles large batches efficiently:

```swift
// Add thousands of documents efficiently
var docs: [Document] = []
for i in 1...10000 {
    docs.append(Document(id: "\(i)", content: "Document \(i)", type: 1, metadata: nil))
}

try await indexer.addItems(docs)

// Remove items - automatically batched in chunks for optimal performance
let idsToRemove = (1...5000).map { "\($0)" }
try await indexer.removeItems(ids: idsToRemove)
```

### Database Cleanup

```swift
// Close the database when done
await dbQueue.close()

// Optimize after many deletions to reclaim space
try await indexer.optimize()

// Rebuild the entire index if needed
try await indexer.reindex()
```

## Complete Basic Example

```swift
import SwiftFTS

// 1. Define your document type
struct BlogPost: FullTextSearchable {
    struct Meta: Codable, Sendable {
        let author: String
        let publishedDate: Date
        let tags: [String]
    }
    
    let id: String
    let title: String
    let body: String
    let meta: Meta
    
    var indexItemID: String { id }
    var indexText: String { "\(title) \(body)" }
    var indexItemType: FTSItemType { 1 }
    var indexMetadata: Meta { meta }
}

// 2. Setup
let dbQueue = try await FTSDatabaseQueue.makeInMemory()
let indexer = try await SearchIndexer(databaseQueue: dbQueue)
let engine = SearchEngine(databaseQueue: dbQueue)

// 3. Index some posts
let post1 = BlogPost(
    id: "swift-intro",
    title: "Introduction to Swift",
    body: "Swift is a powerful and intuitive programming language...",
    meta: BlogPost.Meta(author: "John", publishedDate: Date(), tags: ["swift", "ios"])
)

let post2 = BlogPost(
    id: "swiftui-basics",
    title: "SwiftUI Basics",
    body: "SwiftUI is a declarative framework for building user interfaces...",
    meta: BlogPost.Meta(author: "Jane", publishedDate: Date(), tags: ["swiftui", "ios"])
)

try await indexer.addItems([post1, post2])

// 4. Search
let swiftPosts: [BlogPost] = try await engine.search(query: "Swift", factory: { item in
    BlogPost(
        id: item.id,
        title: "",  // You might want to store this separately
        body: item.text,
        meta: try item.metadata()
    )
})

print("Found \(swiftPosts.count) posts about Swift")

// 5. Complex search
let query = FTSQueryBuilder.andQuery("Swift", "programming")
let results: [BlogPost] = try await engine.search(query: query, factory: { item in
    BlogPost(id: item.id, title: "", body: item.text, meta: try item.metadata())
})

// 6. Cleanup
await dbQueue.close()
```

## Performance Tips

- Use **batched operations** (`addItems`, `removeItems`) instead of individual operations for better performance
- Call `optimize()` periodically after large deletions to reclaim disk space
- Use **type filters** when searching specific categories to improve search speed
- Implement `canIndex` to skip empty or invalid documents
- Use **pagination** for large result sets to improve memory usage
- Consider file-based databases for persistent storage across app launches

## Requirements

- iOS 13.0+
- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+
## Testing

SwiftFTS includes comprehensive tests with 100% code coverage. Run tests with:

```bash
swift test
```

## License

See LICENSE file for details.

