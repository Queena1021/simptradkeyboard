import Foundation

public enum IMEMode: String, Equatable {
    case cangjie
    case quick
}

public final class InputEngine {
    private let cangjieTrie: Trie
    private let quickTrie: Trie

    public init(cangjieTrie: Trie, quickTrie: Trie) {
        self.cangjieTrie = cangjieTrie
        self.quickTrie = quickTrie
    }

    public static func loadFromBundle() throws -> InputEngine {
        try loadFromBundle(.module)
    }

    public static func loadFromBundle(_ bundle: Bundle) throws -> InputEngine {
        let cangjieURL = bundle.url(forResource: "cangjie5", withExtension: "trie")!
        let quickURL = bundle.url(forResource: "quick5", withExtension: "trie")!
        let cangjie = try Trie.decode(from: Data(contentsOf: cangjieURL))
        let quick = try Trie.decode(from: Data(contentsOf: quickURL))
        return InputEngine(cangjieTrie: cangjie, quickTrie: quick)
    }

    public func lookup(code: String, mode: IMEMode) -> [Candidate] {
        guard !code.isEmpty else { return [] }
        switch mode {
        case .cangjie: return cangjieTrie.lookup(key: code)
        case .quick: return quickTrie.lookup(key: code)
        }
    }
}
