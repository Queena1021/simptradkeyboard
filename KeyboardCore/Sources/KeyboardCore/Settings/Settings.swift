import Foundation

public final class Settings {
    private let defaults: UserDefaults

    private enum Key {
        static let outputMode = "outputMode"
        static let imeMode = "imeMode"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public static func shared() -> Settings {
        Settings(defaults: AppGroup.userDefaults() ?? .standard)
    }

    public var outputMode: OutputMode {
        get {
            (defaults.string(forKey: Key.outputMode).flatMap(OutputMode.init(rawValue:))) ?? .simplified
        }
        set { defaults.set(newValue.rawValue, forKey: Key.outputMode) }
    }

    public var imeMode: IMEMode {
        get {
            (defaults.string(forKey: Key.imeMode).flatMap(IMEMode.init(rawValue:))) ?? .quick
        }
        set { defaults.set(newValue.rawValue, forKey: Key.imeMode) }
    }
}
