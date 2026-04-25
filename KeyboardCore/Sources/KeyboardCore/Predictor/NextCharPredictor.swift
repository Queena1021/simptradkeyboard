import Foundation

/// Suggests likely next characters given the just-committed character,
/// using a corpus-derived `[firstChar: [nextChar]]` table.
public final class NextCharPredictor {
    private let table: [String: [String]]

    public init(table: [String: [String]]) {
        self.table = table
    }

    public static func loadFromBundle() throws -> NextCharPredictor {
        try loadFromBundle(.module)
    }

    public static func loadFromBundle(_ bundle: Bundle) throws -> NextCharPredictor {
        let url = bundle.url(forResource: "next_char", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let dict = try JSONDecoder().decode([String: [String]].self, from: data)
        return NextCharPredictor(table: dict)
    }

    /// Returns up to `limit` next-character suggestions for the given prefix character.
    public func suggestions(after char: String, limit: Int = 8) -> [String] {
        guard let list = table[char] else { return [] }
        return Array(list.prefix(limit))
    }
}
