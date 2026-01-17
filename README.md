# SwiftFTS

SwiftFTS is a Swift wrapper around sqlite3 FTS5 for fast and simple full-text search on iOS/macOS.

## Features

- Async/Await API (with backward compatibility)
- Metadata support for index items
- Fast SQLite FTS5 power (ranking, prefix queries)
- Thread-safe `FTSDatabaseQueue`
- No external dependencies
- 100% test coverage

## Installation

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

## Usage

See unit tests (`SwiftFTSTests.swift`) for more detailed usage.

### Setup

```swift
import SwiftFTS

// Create a database (file-based or in-memory)
let dbQueue = try await FTSDatabaseQueue(path: "path/to/db.sqlite")

// Initialize Indexer and Engine
let indexer = try await SearchIndexer(databaseQueue: dbQueue)
let engine = SearchEngine(databaseQueue: dbQueue)
```

### Define Index Items

Adopt `FullTextSearchable` or inherit from `FTSItem`:

```swift
struct MyDocument: FullTextSearchable {
    struct Meta: Codable, Sendable {
        let title: String
        let year: Int
    }
    
    let id: String
    let text: String
    let type: FTSItemType
    let metadata: Meta
    
    var indexItemID: String { id }
    var indexText: String { text }
    var indexItemType: FTSItemType { type }
    var indexMetadata: Meta { metadata }
}
```

### Indexing

```swift
let doc = MyDocument(id: "one", text: "Soli Deo gloria", type: 1, metadata: .init(title: "Glory"))
try await indexer.addItems([doc])
```

### Searching

```swift
let results: [FTSItem<MyDocument.Meta>] = try await engine.search(query: "glory")

for result in results {
    print(result.indexText)
    print(result.indexMetadata?.title)
}
```

## Requirements

- iOS 13.0+
- macOS 13.0+
