import XCTest
@testable import KeyboardCore

final class TrieTests: XCTestCase {
    func test_insertAndLookup_exactMatch() {
        var trie = Trie()
        trie.insert(key: "a", candidate: Candidate(text: "日", frequency: 9999, source: .builtin))
        let result = trie.lookup(key: "a")
        XCTAssertEqual(result, [Candidate(text: "日", frequency: 9999, source: .builtin)])
    }

    func test_insertMultipleForSameKey_returnsAllSortedByFrequency() {
        var trie = Trie()
        trie.insert(key: "a", candidate: Candidate(text: "曰", frequency: 10, source: .builtin))
        trie.insert(key: "a", candidate: Candidate(text: "日", frequency: 9999, source: .builtin))
        let result = trie.lookup(key: "a")
        XCTAssertEqual(result.map(\.text), ["日", "曰"])
    }

    func test_lookup_missingKey_returnsEmpty() {
        let trie = Trie()
        XCTAssertEqual(trie.lookup(key: "xyz"), [])
    }

    func test_lookup_isAutoCompleteFree_prefixDoesNotMatchDeeper() {
        var trie = Trie()
        trie.insert(key: "ap", candidate: Candidate(text: "曰", frequency: 1, source: .builtin))
        XCTAssertEqual(trie.lookup(key: "a"), [])
    }
}
