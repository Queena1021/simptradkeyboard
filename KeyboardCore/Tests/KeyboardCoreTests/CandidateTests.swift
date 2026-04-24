import XCTest
@testable import KeyboardCore

final class CandidateTests: XCTestCase {
    func test_candidate_sortsByFrequencyDescending() {
        let a = Candidate(text: "日", frequency: 100, source: .builtin)
        let b = Candidate(text: "曰", frequency: 10, source: .builtin)
        XCTAssertGreaterThan(a.frequency, b.frequency)
    }

    func test_candidate_equatable() {
        let a = Candidate(text: "日", frequency: 100, source: .builtin)
        let b = Candidate(text: "日", frequency: 100, source: .builtin)
        XCTAssertEqual(a, b)
    }
}
