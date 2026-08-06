import XCTest
// @testable import WisperVoice (logic test - sources compiled in)

final class HistoryStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "wisper.history")
        UserDefaults.standard.removeObject(forKey: "provider")
        HistoryStore.shared.clear()
    }
    override func tearDown() {
        HistoryStore.shared.clear()
        UserDefaults.standard.removeObject(forKey: "wisper.history")
        super.tearDown()
    }

    func testAddInsertsAtFront() {
        let store = HistoryStore.shared
        store.add("first")
        store.add("second")
        XCTAssertEqual(store.items.first?.text, "second")
        XCTAssertEqual(store.items[1].text, "first")
    }

    func testAddEmptyDoesNothing() {
        let store = HistoryStore.shared
        store.add("")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testAddUsesProviderFromUserDefaults() {
        UserDefaults.standard.set("Apple Speech (On-device)", forKey: "provider")
        HistoryStore.shared.add("hello")
        XCTAssertEqual(HistoryStore.shared.items.first?.provider, "Apple Speech (On-device)")
    }

    func testAddUsesEmptyProviderWhenMissing() {
        UserDefaults.standard.removeObject(forKey: "provider")
        HistoryStore.shared.add("hi")
        XCTAssertEqual(HistoryStore.shared.items.first?.provider, "")
    }

    func testLimit100() {
        let store = HistoryStore.shared
        for i in 0..<105 { store.add("item \(i)") }
        XCTAssertEqual(store.items.count, 100)
        XCTAssertEqual(store.items.first?.text, "item 104")
        // oldest 5 should be evicted
        XCTAssertFalse(store.items.contains(where: { $0.text == "item 0"}))
    }

    func testClear() {
        HistoryStore.shared.add("a")
        HistoryStore.shared.add("b")
        HistoryStore.shared.clear()
        XCTAssertTrue(HistoryStore.shared.items.isEmpty)
    }

    func testPersistenceRoundTrip() {
        HistoryStore.shared.add("persist me")
        // Simulate reload by decoding raw data
        let data = UserDefaults.standard.data(forKey: "wisper.history")!
        let decoded = try! JSONDecoder().decode([HistoryItem].self, from: data)
        XCTAssertEqual(decoded.first?.text, "persist me")
    }

    func testHistoryItemCodableEquatable() throws {
        let item = HistoryItem(text: "hello", date: Date(timeIntervalSince1970: 0), provider: "p")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(HistoryItem.self, from: data)
        XCTAssertEqual(item.text, decoded.text)
        XCTAssertEqual(item.provider, decoded.provider)
        XCTAssertEqual(item, decoded)
        // Identifiable
        XCTAssertNotNil(item.id)
    }

    func testItemsDidSetSaves() {
        // DidSet triggered via add already tested; test direct assignment
        let store = HistoryStore.shared
        store.items = [HistoryItem(text: "x", date: Date(), provider: "y")]
        let data = UserDefaults.standard.data(forKey: "wisper.history")
        XCTAssertNotNil(data)
    }
}
