import XCTest
@testable import KeyboardCore

final class EndToEndTests: XCTestCase {
    func test_typeSelectLearn_nextTimeCandidateRanksFirst() throws {
        let input = try InputEngine.loadFromBundle()
        let store = try LearningStore(path: ":memory:")

        // First lookup
        var cands = input.lookup(code: "a", mode: .quick)
        XCTAssertTrue(cands.count >= 2)

        // User selects a non-first candidate
        let selected = cands[1]
        store.recordSelection(code: "a", candidate: selected.text)
        store.recordSelection(code: "a", candidate: selected.text)
        store.recordSelection(code: "a", candidate: selected.text)

        // Next lookup, apply learning boost
        cands = input.lookup(code: "a", mode: .quick)
        cands.sort { lhs, rhs in
            let lb = store.frequencyBoost(code: "a", candidate: lhs.text)
            let rb = store.frequencyBoost(code: "a", candidate: rhs.text)
            if lb != rb { return lb > rb }
            return lhs.frequency > rhs.frequency
        }
        XCTAssertEqual(cands.first?.text, selected.text)
    }

    func test_typeCangjieCodeThenConvertToSimplified() throws {
        let input = try InputEngine.loadFromBundle()
        let conv = try ConvertEngine.loadFromBundle()

        // Cangjie code for 髮 is "shike"
        let cands = input.lookup(code: "shike", mode: .cangjie)
        XCTAssertTrue(cands.contains { $0.text == "髮" }, "expected 髮 among cangjie 'shike' lookups, got: \(cands.map(\.text))")

        let simplified = conv.convert("髮", to: .simplified)
        XCTAssertEqual(simplified, "发")
    }
}
