import Foundation

public struct TextStats: Equatable, Sendable {
    public let characters: Int
    public let words: Int
    public let lines: Int

    public init(_ string: String) {
        characters = string.count
        words = string.split(whereSeparator: \.isWhitespace).count
        var count = 0
        string.enumerateLines { _, _ in count += 1 }
        lines = string.isEmpty ? 0 : count
    }
}
