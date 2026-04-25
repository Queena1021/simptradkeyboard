import Foundation

public enum OutputMode: String, Equatable {
    case simplified
    case traditional
}

public final class ConvertEngine {
    private let phraseDict: [String: String]
    private let charDict: [String: String]
    private let maxPhraseLength: Int

    public init(phraseDict: [String: String], charDict: [String: String]) {
        self.phraseDict = phraseDict
        self.charDict = charDict
        self.maxPhraseLength = phraseDict.keys.map { $0.count }.max() ?? 0
    }

    public static func loadFromBundle() throws -> ConvertEngine {
        try loadFromBundle(.module)
    }

    public static func loadFromBundle(_ bundle: Bundle) throws -> ConvertEngine {
        let phrasesURL = bundle.url(forResource: "t2s_phrases", withExtension: "json")!
        let charsURL = bundle.url(forResource: "t2s_chars", withExtension: "json")!
        let phrases = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: phrasesURL))
        let chars = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: charsURL))
        return ConvertEngine(phraseDict: phrases, charDict: chars)
    }

    public func convert(_ text: String, to mode: OutputMode) -> String {
        guard mode == .simplified else { return text }
        guard !text.isEmpty else { return text }
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            // Longest-match phrase scan
            var matched = false
            let maxLen = min(maxPhraseLength, chars.count - i)
            if maxLen >= 2 {
                var len = maxLen
                while len >= 2 {
                    let candidate = String(chars[i..<i+len])
                    if let mapped = phraseDict[candidate] {
                        result += mapped
                        i += len
                        matched = true
                        break
                    }
                    len -= 1
                }
            }
            if !matched {
                let single = String(chars[i])
                result += charDict[single] ?? single
                i += 1
            }
        }
        return result
    }
}
