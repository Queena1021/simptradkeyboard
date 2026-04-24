import XCTest
@testable import KeyboardCore

final class PackageSmokeTests: XCTestCase {
    func test_version_isNotEmpty() {
        XCTAssertFalse(KeyboardCore.version.isEmpty)
    }
}
