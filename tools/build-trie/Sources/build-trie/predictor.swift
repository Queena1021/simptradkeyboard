import Foundation

enum NextCharBuilder {
    /// Build a JSON dict mapping each first char to top-N next chars by frequency,
    /// derived from one or more rime-essay-format phrase corpora.
    /// Output format: { "我": ["們", "的", "是", ...], ... }
    static func build(from inputPaths: [String], to outputPath: String, topN: Int = 12) throws {
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
                let first = chars[0]
                let second = chars[1]
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

    private static func isCJK(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        let v = scalar.value
        return (0x4E00 ... 0x9FFF).contains(v) || (0x3400 ... 0x4DBF).contains(v)
    }
}
