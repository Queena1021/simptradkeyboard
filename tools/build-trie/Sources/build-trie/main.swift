import Foundation
import KeyboardCore

let args = CommandLine.arguments

func usage() -> Never {
    FileHandle.standardError.write(Data("""
Usage:
  build-trie trie <input.yaml> <output.trie>
  build-trie opencc <input.txt> <output.json>

""".utf8))
    exit(2)
}

guard args.count >= 4 else { usage() }

switch args[1] {
case "trie":
    let inputPath = args[2]
    let outputPath = args[3]
    let content = try String(contentsOfFile: inputPath, encoding: .utf8)
    var inBody = false
    var trie = Trie()
    var count = 0
    for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let s = String(line)
        if !inBody { if s.hasPrefix("...") { inBody = true }; continue }
        if s.isEmpty || s.hasPrefix("#") { continue }
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
case "opencc":
    try OpenCCBuilder.buildDict(from: args[2], to: args[3])
default:
    usage()
}
