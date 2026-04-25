import Foundation
import KeyboardCore

let args = CommandLine.arguments

func usage() -> Never {
    FileHandle.standardError.write(Data("""
Usage:
  build-trie trie <input.yaml> <freq.txt> <output.trie>
  build-trie quick-from-cangjie <cangjie.yaml> <freq.txt> <output.trie>
  build-trie opencc <input.txt> <output.json>
  build-trie predictor <output.json> <TSCharacters.txt> <freq1.txt> [<freq2.txt> ...]

freq.txt: rime essay format (one row per char or phrase, "<text>\\t<weight>")

""".utf8))
    exit(2)
}

guard args.count >= 4 else { usage() }

/// Load single-character frequencies from rime essay file. Returns
/// [text: weight] for entries whose text is exactly one Unicode char.
func loadCharFreq(_ path: String) throws -> [String: Int] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    var dict: [String: Int] = [:]
    for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { continue }
        let text = String(parts[0])
        guard text.count == 1 else { continue }
        guard let w = Int(parts[1]) else { continue }
        dict[text] = w
    }
    return dict
}

switch args[1] {
case "trie":
    guard args.count >= 5 else { usage() }
    let inputPath = args[2]
    let freqPath = args[3]
    let outputPath = args[4]
    let freqDict = try loadCharFreq(freqPath)
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
        let weight = freqDict[text] ?? 0
        trie.insert(key: code, candidate: Candidate(text: text, frequency: weight, source: .builtin))
        count += 1
    }
    let data = try trie.encode()
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(count) entries (\(data.count) bytes) to \(outputPath)")
case "quick-from-cangjie":
    guard args.count >= 5 else { usage() }
    let inputPath = args[2]
    let freqPath = args[3]
    let outputPath = args[4]
    let freqDict = try loadCharFreq(freqPath)
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
        let cangjieCode = String(parts[1])
        let weight = freqDict[text] ?? 0
        guard !cangjieCode.isEmpty else { continue }
        let quickCode: String
        if cangjieCode.count == 1 {
            quickCode = cangjieCode
        } else {
            quickCode = String(cangjieCode.first!) + String(cangjieCode.last!)
        }
        trie.insert(key: quickCode, candidate: Candidate(text: text, frequency: weight, source: .builtin))
        count += 1
    }
    let data = try trie.encode()
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(count) entries (\(data.count) bytes) to \(outputPath)")
case "opencc":
    try OpenCCBuilder.buildDict(from: args[2], to: args[3])
case "predictor":
    guard args.count >= 5 else { usage() }
    let outputPath = args[2]
    let charsTSV = args[3]
    let inputs = Array(args.dropFirst(4))
    try NextCharBuilder.build(from: inputs, to: outputPath, charsTSV: charsTSV)
default:
    usage()
}
