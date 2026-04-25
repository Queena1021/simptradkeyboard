import XCTest
@testable import KeyboardCore

final class PerformanceTests: XCTestCase {
    func test_perf_trieLookup() throws {
        let engine = try InputEngine.loadFromBundle()
        measure {
            for _ in 0..<1000 {
                _ = engine.lookup(code: "a", mode: .quick)
            }
        }
    }

    func test_perf_convertTenChars() throws {
        let conv = try ConvertEngine.loadFromBundle()
        let text = String(repeating: "我發現了頭髮飛舞", count: 1)
        measure {
            for _ in 0..<100 {
                _ = conv.convert(text, to: .simplified)
            }
        }
    }
}
