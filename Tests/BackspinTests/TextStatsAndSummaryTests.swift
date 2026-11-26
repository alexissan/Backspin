import Foundation
import Testing
@testable import BackspinCore

@Suite struct TextStatsTests {
    @Test(arguments: [
        ("", 0, 0, 0), ("hello", 5, 1, 1), ("hello world", 11, 2, 1), ("a\nb", 3, 2, 2),
        ("a\nb\n", 4, 2, 2), ("a\n\nb", 4, 2, 3), ("\n", 1, 0, 1), ("a\r\nb", 3, 2, 2),
        ("  spaced   out  ", 16, 2, 1), ("é👨‍👩‍👧 x", 4, 2, 1), ("one\ttwo\nthree four", 18, 4, 2),
    ])
    func counts(_ text: String, _ chars: Int, _ words: Int, _ lines: Int) {
        let stats = TextStats(text)
        #expect(stats.characters == chars)
        #expect(stats.words == words)
        #expect(stats.lines == lines)
    }
}

@Suite struct ClipSummaryTests {
    private func item(_ kind: ClipKind, _ text: String?) -> ClipItem {
        ClipItem(kind: kind, text: text, contentHash: "h")
    }

    @Test func firstNonBlankLineCollapsed() {
        #expect(item(.text, "\n  \n   hello \t  world  \nsecond").summary == "hello world")
    }

    @Test func emptyWhenNoText() {
        #expect(item(.image, nil).summary == "")
        #expect(item(.text, "   \n ").summary == "")
        #expect(item(.file, nil).summary == "")
    }

    @Test func capsAt200() {
        #expect(item(.text, String(repeating: "x", count: 500)).summary.count == 200)
    }

    @Test func fileSummaryUsesFirstPathLastComponent() {
        #expect(item(.file, "/Users/a/Docs/report.pdf").summary == "report.pdf")
        #expect(item(.file, "/Users/a/Docs/report.pdf\n/tmp/other.txt").summary == "report.pdf")
    }

    @Test func fileURLs() {
        let urls = item(.file, "/a/b.txt\n\n /c/d e.png \n").fileURLs
        #expect(urls.map(\.path) == ["/a/b.txt", "/c/d e.png"])
        #expect(urls.allSatisfy { $0.isFileURL })
        #expect(item(.text, "/a/b.txt").fileURLs.isEmpty)
        #expect(item(.file, nil).fileURLs.isEmpty)
    }
}
