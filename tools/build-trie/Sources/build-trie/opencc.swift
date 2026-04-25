import Foundation

public enum OpenCCBuilder {
    /// Transforms rows of "<traditional>\t<simplified>[ <alt> ...]" into [String: String]
    /// (first simplified variant is kept — canonical mapping).
    public static func buildDict(from inputPath: String, to outputPath: String) throws {
        let content = try String(contentsOfFile: inputPath, encoding: .utf8)
        var dict: [String: String] = [:]
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count == 2 else { continue }
            let trad = String(parts[0])
            let simpFirst = String(parts[1].split(separator: " ").first ?? "")
            guard !simpFirst.isEmpty else { continue }
            dict[trad] = simpFirst
        }
        let data = try JSONEncoder().encode(dict)
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(dict.count) entries (\(data.count) bytes) to \(outputPath)")
    }
}
