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
    
    @Test("Remove Single Item")
    func testRemoveItem() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        // Add multiple documents
        let doc1 = TestDocument(id: "doc1", text: "First document about Swift", metadata: TestMetadata(author: "Chris", year: 2023))
        let doc2 = TestDocument(id: "doc2", text: "Second document about Swift", metadata: TestMetadata(author: "Caleb", year: 2024))
        let doc3 = TestDocument(id: "doc3", text: "Third document about Python", metadata: TestMetadata(author: "Josiah", year: 2025))
        
        try await indexer.addItems([doc1, doc2, doc3])
        
        // Verify all documents are indexed
        let initialCount = try await indexer.count()
        #expect(initialCount == 3)
        
        // Search to confirm all Swift docs exist
        let swiftResults: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Swift")
        #expect(swiftResults.count == 2)
        
        // Remove a single item
        try await indexer.removeItem(id: "doc1")
        
        // Verify count decreased by 1
        let afterRemovalCount = try await indexer.count()
        #expect(afterRemovalCount == 2)
        
        // Verify the removed item is no longer searchable
        let afterRemovalResults: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Swift")
        #expect(afterRemovalResults.count == 1)
        #expect(afterRemovalResults.first?.indexItemID == "doc2")
        
        // Verify other documents are still present
        let pythonResults: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Python")
        #expect(pythonResults.count == 1)
        #expect(pythonResults.first?.indexItemID == "doc3")
        
        // Remove non-existent item (should not throw)
        try await indexer.removeItem(id: "nonexistent")
        let finalCount = try await indexer.count()
        #expect(finalCount == 2)
        
        await dbQueue.close()
    }
    
    @Test("Remove Multiple Items")
    func testRemoveItems() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        
        // Add multiple documents
        var docs: [TestDocument] = []
        for idx in 1...10 {
            docs.append(TestDocument(id: "doc\(idx)", text: "Document \(idx) with searchable content", type: FTSItemType(idx % 3)))
        }
        try await indexer.addItems(docs)
        
        // Verify all documents are indexed
        let initialCount = try await indexer.count()
        #expect(initialCount == 10)
        
        // Remove multiple items (3 documents)
        try await indexer.removeItems(ids: ["doc1", "doc3", "doc5"])
        
        // Verify count decreased by 3
        let afterRemovalCount = try await indexer.count()
        #expect(afterRemovalCount == 7)
        
        // Verify removed items are no longer searchable
        let allResults: [any FullTextSearchable<TestMetadata>] = try await engine.search(query: "Document")
        #expect(allResults.count == 7)
        
        let removedIds = Set(["doc1", "doc3", "doc5"])
        for result in allResults {
            #expect(!removedIds.contains(result.indexItemID))
        }
        
        // Verify remaining documents are correct
        let remainingIds = allResults.map { $0.indexItemID }
        #expect(remainingIds.contains("doc2"))
        #expect(remainingIds.contains("doc4"))
        #expect(remainingIds.contains("doc6"))
        #expect(remainingIds.contains("doc7"))
        #expect(remainingIds.contains("doc8"))
        #expect(remainingIds.contains("doc9"))
        #expect(remainingIds.contains("doc10"))
        
        // Test removing with empty array (should not throw)
        try await indexer.removeItems(ids: [])
        let countAfterEmpty = try await indexer.count()
        #expect(countAfterEmpty == 7)
        
        // Test removing with mix of existing and non-existing IDs
        try await indexer.removeItems(ids: ["doc2", "nonexistent", "doc4"])
        let finalCount = try await indexer.count()
        #expect(finalCount == 5)
        
        await dbQueue.close()
    }
    
    @Test("Remove Items in Large Batches")
    func testRemoveItemsLargeBatch() async throws {
        let dbQueue = try await FTSDatabaseQueue.makeInMemory()
        let indexer = try await SearchIndexer(databaseQueue: dbQueue)
        let engine = SearchEngine(databaseQueue: dbQueue)
        let maxDocsToIndex = 2000
        
        // Add 2000 documents (more than SQLInBatchSize of 900)
        var docs: [TestDocument] = []
        for idx in 1...maxDocsToIndex {
            docs.append(TestDocument(id: "doc\(idx)", text: "Batch test document \(idx)"))
        }
        try await indexer.addItems(docs)
        
        // Verify all documents are indexed
        let initialCount = try await indexer.count()
        #expect(initialCount == maxDocsToIndex)
        
        // Remove 1500 items (requires multiple batches)
        var idsToRemove: [String] = []
        for idx in 1...1500 {
            idsToRemove.append("doc\(idx)")
        }
        try await indexer.removeItems(ids: idsToRemove)
        
        // Verify correct count after removal
        let afterRemovalCount = try await indexer.count()
        #expect(afterRemovalCount == 500)
        
        // Verify removed items are gone
        let results: [any FullTextSearchable<TestMetadata?>] = try await engine.search(query: "Batch", limit: maxDocsToIndex)
        #expect(results.count == 500)
        
        // Verify remaining IDs are correct (doc1501 through doc2000)
        let remainingIds = Set(results.map { $0.indexItemID })
        for idx in 1501...maxDocsToIndex {
            #expect(remainingIds.contains("doc\(idx)"))
        }
        
        // Verify removed IDs are not present
        for idx in 1...1500 {
            #expect(!remainingIds.contains("doc\(idx)"))
        }
        
        await dbQueue.close()
    }
}
