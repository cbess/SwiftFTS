import Testing
import Foundation
@testable import SwiftFTS

struct TestMetadata: Codable, Equatable, Sendable {
    let author: String
    let year: Int
}

struct TestDocument: FullTextSearchable {
    let id: String
    let text: String
    let type: FTSItemType
    let metadata: TestMetadata?
    
    var indexItemID: String { id }
    var indexText: String { text }
    var indexItemType: FTSItemType { type }
    var indexMetadata: TestMetadata? { metadata }
    
    init(id: String, text: String, type: FTSItemType = FTSItemTypeUnspecified, metadata: TestMetadata? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.metadata = metadata
    }
}

@Suite("SwiftFTS Tests")
struct SwiftFTSTests {
    
    @Test("Simple Indexing")
    func testSimpleSearch() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        let doc = TestDocument(id: "1", text: "Hello, world!", type: 1, metadata: nil)
        try await indexer.addItems([doc])
        
        // find it
        let results: [any FullTextSearchable<TestMetadata?>] = try await engine.search(query: "woRld")
        #expect(results.count == 1)
        #expect(results.first?.indexItemType == 1)
    }
    
    @Test("Basic Indexing and Searching")
    func testIndexingAndSearching() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        let doc1 = TestDocument(id: "1", text: "Swift is a powerful programming language.", type: FTSItemTypeUnspecified, metadata: TestMetadata(author: "Apple", year: 2014))
        let doc2 = TestDocument(id: "2", text: "Objective-C was the primary language for iOS.", type: 1, metadata: TestMetadata(author: "NeXT", year: 1984))
        let doc3 = TestDocument(id: "3", text: "Python is great for data science.", type: 2, metadata: nil)
        
        try await indexer.addItems([doc1, doc2, doc3])
        
        // Search for "Swift"
        let results1: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Swift")
        #expect(results1.count == 1)
        #expect(results1.first?.indexItemID == "1")
        #expect(results1.first?.indexMetadata?.author == "Apple")
        
        // Search for "language" (should match 1 and 2)
        let results2: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "language")
        #expect(results2.count == 2)
        
        // Search for "language" with type filter 1
        let results3: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "language", itemType: 1)
        #expect(results3.count == 1)
        
        // Search for "language" with type filter 2
        let results4: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "language", itemType: 2)
        #expect(results4.isEmpty)

        // Search for "data" type 2
        let results5: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "data", itemType: 2)
        #expect(results5.count == 1)
        #expect(results5.first?.indexItemID == "3")
        
        await dbQueue.close()
    }
    
    @Test("Update and Remove")
    func testUpdateAndRemove() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        let doc1 = TestDocument(id: "1", text: "Hello World", metadata: TestMetadata(author: "Me", year: 2023))
        try await indexer.addItems([doc1])
        
        let results1: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Hello")
        #expect(results1.count == 1)
        #expect(results1.first?.indexText == "Hello World")
        #expect(results1.first?.indexMetadata?.year == 2023)
        
        // Update
        let doc1Updated = TestDocument(id: "1", text: "Hello Swift", metadata: TestMetadata(author: "Me", year: 2024))
        try await indexer.updateItem(doc1Updated)
        
        let results2: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Hello")
        #expect(results2.count == 1)
        #expect(results2.first?.indexText == "Hello Swift")
        // check updated metadata
        #expect(results2.first?.indexMetadata?.year == 2024)
        
        let results3: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "World")
        #expect(results3.isEmpty)
        
        // remove doc
        try await indexer.removeItem(id: "1")
        let results4: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Hello")
        #expect(results4.isEmpty)
        
        // test the optimize operation
        try await indexer.optimize()
        
        await dbQueue.close()
    }
    
    @Test("Pagination")
    func testPagination() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        var docs: [TestDocument] = []
        for idx in 0..<10 {
            docs.append(TestDocument(id: "\(idx)", text: "page item key", type: 1, metadata: TestMetadata(author: "Bot", year: idx)))
        }
        try await indexer.addItems(docs)
        
        // Page 1
        let page1: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "item", offset: 0, limit: 3)
        #expect(page1.count == 3)
        
        // Page 2
        let page2: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "item", offset: 3, limit: 3)
        #expect(page2.count == 3)
        
        // Page 4 (remaining 1)
        let page4: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "item", offset: 9, limit: 3)
        #expect(page4.count == 1)
        
        await dbQueue.close()
    }
    
    @Test("Trigger Synchronization")
    func testTriggerSynchronization() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        let doc = TestDocument(id: "doc1", text: "trigger test initial", metadata: TestMetadata(author: "Tester", year: 2025))
        try await indexer.addItems([doc])
        
        // Confirm exists
        let results1: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "initial")
        #expect(results1.count == 1)
        
        // Remove doc - validates fts_lookup_ad trigger or DELETE behavior
        try await indexer.removeItem(id: "doc1")
        
        // Confirm gone from FTS
        let results2: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "initial")
        #expect(results2.isEmpty)
        
        // Re-add to test update (replace)
        try await indexer.addItems([doc])
        let results3: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "initial")
        #expect(results3.count == 1)
        #expect(results3.first!.indexMetadata?.year == 2025)
        
        // Update doc (change text) - validates DELETE+INSERT (via REPLACE) behavior keeping FTS in sync
        let docUpdated = TestDocument(id: "doc1", text: "trigger test updated")
        try await indexer.updateItem(docUpdated)
        
        // test reindex operation
        try await indexer.reindex()
        
        // Confirm old text gone
        let results4: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "initial")
        #expect(results4.isEmpty)
        
        // Confirm common text present (retained across update)
        let resultsCommon: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "trigger")
        #expect(resultsCommon.count == 1)
        
        // Confirm new text present
        let results5: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "updated")
        #expect(results5.count == 1)
        #expect(results5.first!.indexMetadata == nil)
        
        await dbQueue.close()
    }

    @Test("Count")
    func testCount() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        
        // initial count
        let count0 = try await indexer.count()
        #expect(count0 == 0)
        
        let doc1 = TestDocument(id: "1", text: "One")
        let doc2 = TestDocument(id: "2", text: "Two")
        
        // add docs
        try await indexer.addItems([doc1, doc2])
        
        // count after addition
        let count2 = try await indexer.count()
        #expect(count2 == 2)
        
        try await indexer.removeItem(id: "1")
        
        // count after removal
        let count1 = try await indexer.count()
        #expect(count1 == 1)
        
        await dbQueue.close()
    }
}
