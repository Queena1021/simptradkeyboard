import Foundation

public struct Candidate: Equatable, Hashable {
    public enum Source: String, Equatable, Hashable {
        case builtin
        case learned
    }

    public let text: String
    public let frequency: Int
    public let source: Source

    public init(text: String, frequency: Int, source: Source) {
        self.text = text
        self.frequency = frequency
        self.source = source
    }
}
