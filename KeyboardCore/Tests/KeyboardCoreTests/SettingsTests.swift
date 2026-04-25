import XCTest
@testable import KeyboardCore

final class SettingsTests: XCTestCase {
    var defaults: UserDefaults!
    var settings: Settings!

    override func setUp() {
        defaults = UserDefaults(suiteName: "SettingsTests-\(UUID().uuidString)")
        settings = Settings(defaults: defaults)
    }

    func test_defaults_outputMode_isSimplified() {
        XCTAssertEqual(settings.outputMode, .simplified)
    }

    func test_defaults_imeMode_isQuick() {
        XCTAssertEqual(settings.imeMode, .quick)
    }

    func test_setOutputMode_persists() {
        settings.outputMode = .simplified
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.outputMode, .simplified)
    }

    func test_setImeMode_persists() {
        settings.imeMode = .cangjie
        let reloaded = Settings(defaults: defaults)
        XCTAssertEqual(reloaded.imeMode, .cangjie)
    }
}
