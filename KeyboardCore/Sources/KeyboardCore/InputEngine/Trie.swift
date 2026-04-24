import Foundation

public struct Trie {
    private final class Node {
        var children: [Character: Node] = [:]
        var candidates: [Candidate] = []
    }

    private let root = Node()

    public init() {}

    public mutating func insert(key: String, candidate: Candidate) {
        var node = root
        for ch in key {
            if let child = node.children[ch] {
                node = child
            } else {
                let child = Node()
                node.children[ch] = child
                node = child
            }
        }
        node.candidates.append(candidate)
        node.candidates.sort { $0.frequency > $1.frequency }
    }

    public func lookup(key: String) -> [Candidate] {
        var node = root
        for ch in key {
            guard let next = node.children[ch] else { return [] }
            node = next
        }
        return node.candidates
    }
}

extension Trie {
    fileprivate struct Entry: Codable {
        let key: String
        let text: String
        let frequency: Int
    }

    public func encode() throws -> Data {
        var entries: [Entry] = []
        collect(node: root, prefix: "", into: &entries)
        return try JSONEncoder().encode(entries)
    }

    public static func decode(from data: Data) throws -> Trie {
        let entries = try JSONDecoder().decode([Entry].self, from: data)
        var trie = Trie()
        for e in entries {
            trie.insert(key: e.key, candidate: Candidate(text: e.text, frequency: e.frequency, source: .builtin))
        }
        return trie
    }

    private func collect(node: Node, prefix: String, into entries: inout [Entry]) {
        for c in node.candidates {
            entries.append(Entry(key: prefix, text: c.text, frequency: c.frequency))
        }
        for (ch, child) in node.children {
            collect(node: child, prefix: prefix + String(ch), into: &entries)
        }
    }
}
