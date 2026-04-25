import XCTest
@testable import KeyboardCore

final class LearningStoreTests: XCTestCase {
    var store: LearningStore!

    override func setUpWithError() throws {
        store = try LearningStore(path: ":memory:")
    }

    func test_frequencyBoost_unknownReturnsZero() {
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 0)
    }

    func test_recordSelection_incrementsCount() {
        store.recordSelection(code: "a", candidate: "日")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 1)
        store.recordSelection(code: "a", candidate: "日")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 2)
    }

    func test_recordSelection_isolatesByCandidate() {
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "a", candidate: "曰")
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 2)
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "曰"), 1)
    }

    func test_reset_clearsAllEntries() {
        store.recordSelection(code: "a", candidate: "日")
        store.reset()
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 0)
    }

    func test_allEntries_returnsRecorded() {
        store.recordSelection(code: "a", candidate: "日")
        store.recordSelection(code: "b", candidate: "月")
        let entries = store.allEntries()
        XCTAssertEqual(entries.count, 2)
    }

    func test_concurrentWrites_noCrash() {
        let exp = expectation(description: "concurrent")
        exp.expectedFulfillmentCount = 100
        for i in 0..<100 {
            DispatchQueue.global().async {
                self.store.recordSelection(code: "a", candidate: "日")
                if i % 10 == 0 {
                    _ = self.store.frequencyBoost(code: "a", candidate: "日")
                }
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 5)
        XCTAssertEqual(store.frequencyBoost(code: "a", candidate: "日"), 100)
    }
}
