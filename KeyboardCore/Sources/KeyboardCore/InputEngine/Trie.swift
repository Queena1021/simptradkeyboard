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
