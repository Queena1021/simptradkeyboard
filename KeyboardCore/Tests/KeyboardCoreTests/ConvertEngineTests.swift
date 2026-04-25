import XCTest
@testable import KeyboardCore

final class ConvertEngineTests: XCTestCase {
    var engine: ConvertEngine!

    override func setUpWithError() throws {
        engine = try ConvertEngine.loadFromBundle()
    }

    func test_convert_T2S_singleChar_fa() {
        XCTAssertEqual(engine.convert("發", to: .simplified), "发")
    }

    func test_convert_T2S_phraseOrCharProducesCorrectSimplified_touFa() {
        XCTAssertEqual(engine.convert("頭髮", to: .simplified), "头发")
    }

    func test_convert_T2S_phraseOrCharProducesCorrectSimplified_faZhan() {
        XCTAssertEqual(engine.convert("發展", to: .simplified), "发展")
    }

    func test_convert_T2S_noMatch_returnsInput() {
        XCTAssertEqual(engine.convert("xyz", to: .simplified), "xyz")
    }

    func test_convert_T2S_mixedText() {
        XCTAssertEqual(engine.convert("我發現了", to: .simplified), "我发现了")
    }

    func test_convert_traditional_isPassthrough_inV1() {
        // V1 does not implement S→T; .traditional returns input unchanged.
        XCTAssertEqual(engine.convert("发", to: .traditional), "发")
    }

    func test_convert_empty() {
        XCTAssertEqual(engine.convert("", to: .simplified), "")
    }
}
