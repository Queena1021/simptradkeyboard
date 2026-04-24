import XCTest
@testable import KeyboardCore

final class TrieResourceTests: XCTestCase {
    func test_cangjie5_loads() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "cangjie5", withExtension: "trie"))
        let data = try Data(contentsOf: url)
        let trie = try Trie.decode(from: data)
        // 「日」in Cangjie is code "a"
        let cands = trie.lookup(key: "a")
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }

    func test_quick5_loads() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "quick5", withExtension: "trie"))
        let data = try Data(contentsOf: url)
        let trie = try Trie.decode(from: data)
        // 「日」Quick code is "a" (single-code)
        let cands = trie.lookup(key: "a")
        XCTAssertTrue(cands.contains { $0.text == "日" })
    }
}
