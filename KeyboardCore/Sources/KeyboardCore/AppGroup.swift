import Foundation

public enum AppGroup {
    /// The App Group identifier shared between the main app and the keyboard extension.
    /// Must match the value configured in both `.entitlements` files.
    public static let identifier = "group.com.qqna.simptradkb"

    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static func userDefaults() -> UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static func learningDBURL() -> URL? {
        containerURL()?.appendingPathComponent("learning.sqlite")
    }
}
