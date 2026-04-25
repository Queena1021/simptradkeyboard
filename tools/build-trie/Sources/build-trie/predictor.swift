import Foundation

enum NextCharBuilder {
    /// Build a JSON dict mapping each first char (Simplified) to top-N next
    /// chars (Simplified) by frequency, derived from rime-essay-format corpora.
    /// All keys/values are normalized to Simplified using OpenCC TSCharacters
    /// so the runtime can look up by either traditional or simplified prefix
    /// after a single T→S conversion step.
    static func build(from inputPaths: [String], to outputPath: String, charsTSV: String, topN: Int = 12) throws {
        let t2s = try loadCharMap(charsTSV)

        var counts: [Character: [Character: Int]] = [:]

        for path in inputPaths {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count >= 2 else { continue }
                let text = parts[0]
                guard text.count >= 2 else { continue }
                guard let weight = Int(parts[1]) else { continue }
                guard weight > 0 else { continue }
                let chars = Array(text)
                let first = normalize(chars[0], with: t2s)
                let second = normalize(chars[1], with: t2s)
                guard isCJK(first) && isCJK(second) else { continue }
                counts[first, default: [:]][second, default: 0] += weight
            }
        }

        var result: [String: [String]] = [:]
        for (first, nexts) in counts {
            let sorted = nexts.sorted { $0.value > $1.value }
                .prefix(topN)
                .map { String($0.key) }
            result[String(first)] = Array(sorted)
        }

        let data = try JSONEncoder().encode(result)
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(result.count) prefix entries (\(data.count) bytes) to \(outputPath)")
    }

    private static func loadCharMap(_ path: String) throws -> [Character: Character] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var dict: [Character: Character] = [:]
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 2 else { continue }
            let trad = String(parts[0])
            let simpFirst = parts[1].split(separator: " ").first.map(String.init) ?? ""
            guard let t = trad.first, let s = simpFirst.first, trad.count == 1 else { continue }
            dict[t] = s
        }
        return dict
    }

    private static func normalize(_ c: Character, with map: [Character: Character]) -> Character {
        return map[c] ?? c
    }

    private static func isCJK(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        let v = scalar.value
        return (0x4E00 ... 0x9FFF).contains(v) || (0x3400 ... 0x4DBF).contains(v)
    }
}
