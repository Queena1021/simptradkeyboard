import Foundation
import KeyboardCore

// Usage: build-trie <input.dict.yaml> <output.trie>

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: build-trie <input.yaml> <output.trie>\n".utf8))
    exit(2)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let content = try String(contentsOfFile: inputPath, encoding: .utf8)

// Skip YAML header (everything up to and including "..." line)
var inBody = false
var trie = Trie()
var count = 0

for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
    let s = String(line)
    if !inBody {
        if s.hasPrefix("...") { inBody = true }
        continue
    }
    if s.isEmpty || s.hasPrefix("#") { continue }
    // Rime table rows: "<text>\t<code>[\t<weight>]"
    let parts = s.split(separator: "\t", omittingEmptySubsequences: false)
    guard parts.count >= 2 else { continue }
    let text = String(parts[0])
    let code = String(parts[1])
    let weight = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
    trie.insert(key: code, candidate: Candidate(text: text, frequency: weight, source: .builtin))
    count += 1
}

let data = try trie.encode()
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(count) entries (\(data.count) bytes) to \(outputPath)")
