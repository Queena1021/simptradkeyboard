import XCTest
@testable import KeyboardCore

final class InputEngineTests: XCTestCase {
    var engine: InputEngine!

    override func setUpWithError() throws {
        engine = try InputEngine.loadFromBundle()
    }

    func test_lookup_quick_singleCode_returnsExpectedCandidates() {
        let cands = engine.lookup(code: "a", mode: .quick)
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_lookup_cangjie_fullCode_returnsExactCharacter() {
        // 「日」Cangjie code is "a"
        let cands = engine.lookup(code: "a", mode: .cangjie)
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_lookup_invalidCode_returnsEmpty() {
        XCTAssertEqual(engine.lookup(code: "zzzzz", mode: .cangjie), [])
    }

    func test_lookup_emptyCode_returnsEmpty() {
        XCTAssertEqual(engine.lookup(code: "", mode: .cangjie), [])
    }
}
