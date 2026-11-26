import Foundation
import Testing
@testable import BackspinCore

private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

private func clip(
    _ text: String, kind: ClipKind = .text, at seconds: Double = 0, pinned: Bool = false,
    hash: String? = nil, source: String? = nil
) -> ClipItem {
    ClipItem(
        kind: kind, text: text, sourceName: source, firstCopiedAt: at(seconds),
        isPinned: pinned, contentHash: hash ?? ContentClassifier.contentHash(text: text)
    )
}

@Suite struct ClipHistoryTests {
    @Test func initSortsNewestFirstAndAppliesLimit() {
        let history = ClipHistory(items: [clip("a", at: 1), clip("c", at: 3), clip("b", at: 2)], limit: 2)
        #expect(history.items.compactMap(\.text) == ["c", "b"])
        #expect(ClipHistory(limit: 0).limit == 1)
        #expect(ClipHistory().limit == ClipHistory.defaultLimit)
    }

    @Test func recordNewGoesToFront() {
        var history = ClipHistory()
        history.record(clip("a", at: 1))
        let outcome = history.record(clip("b", at: 2))
        #expect(!outcome.wasRepeat)
        #expect(outcome.evicted.isEmpty)
        #expect(outcome.item.text == "b")
        #expect(history.items.compactMap(\.text) == ["b", "a"])
    }

    @Test func repeatBumpsAndKeepsIdentity() {
        var history = ClipHistory()
        var original = clip("a", at: 1, source: "Xcode")
        original.richTextFile = "a.rtf"
        original.sourceBundleID = "com.apple.dt.Xcode"
        history.record(original)
        history.record(clip("b", at: 2))
        history.togglePin(id: original.id)

        var again = clip("a", at: 10, source: "Safari")
        again.sourceBundleID = "com.apple.Safari"
        let outcome = history.record(again)

        #expect(outcome.wasRepeat)
        #expect(outcome.item.id == original.id)
        #expect(outcome.item.isPinned)
        #expect(outcome.item.firstCopiedAt == at(1))
        #expect(outcome.item.lastCopiedAt == at(10))
        #expect(outcome.item.copyCount == 2)
        #expect(outcome.item.richTextFile == "a.rtf")
        #expect(outcome.item.sourceName == "Safari")
        #expect(outcome.item.sourceBundleID == "com.apple.Safari")
        #expect(history.items.count == 2)
        #expect(history.items.first?.id == original.id)
    }

    @Test func repeatWithoutSourceKeepsOldSource() {
        var history = ClipHistory()
        history.record(clip("a", at: 1, source: "Xcode"))
        let outcome = history.record(clip("a", at: 2))
        #expect(outcome.item.sourceName == "Xcode")
    }

    @Test func sameHashDifferentKindIsNotRepeat() {
        var history = ClipHistory()
        history.record(clip("x", kind: .text, hash: "H"))
        let outcome = history.record(clip("x", kind: .link, hash: "H"))
        #expect(!outcome.wasRepeat)
        #expect(history.items.count == 2)
    }

    @Test func limitEvictsOldestUnpinnedOnly() {
        var history = ClipHistory(limit: 2)
        let pinned = clip("p", at: 1, pinned: true)
        history.record(pinned)
        history.record(clip("a", at: 2))
        history.record(clip("b", at: 3))
        let outcome = history.record(clip("c", at: 4))
        #expect(outcome.evicted.compactMap(\.text) == ["a"])
        #expect(history.items.compactMap(\.text) == ["c", "b", "p"])
        #expect(history.count(of: nil) == 3)
    }

    @Test func pinnedNeverEvicted() {
        var history = ClipHistory(items: (0..<5).map { clip("p\($0)", at: Double($0), pinned: true) }, limit: 1)
        #expect(history.items.count == 5)
        let outcome = history.record(clip("new", at: 10))
        #expect(outcome.evicted.isEmpty)
        #expect(history.items.count == 6)
    }

    @Test func setLimitEvicts() {
        var history = ClipHistory(items: [clip("a", at: 1), clip("b", at: 2), clip("c", at: 3, pinned: true), clip("d", at: 4)])
        let evicted = history.setLimit(1)
        #expect(evicted.compactMap(\.text) == ["b", "a"])
        #expect(history.items.compactMap(\.text) == ["d", "c"])
        #expect(history.setLimit(-5).isEmpty)
        #expect(history.limit == 1)
        #expect(history.setLimit(100).isEmpty)
    }

    @Test func removeAndLookup() {
        let a = clip("a", at: 1)
        var history = ClipHistory(items: [a])
        #expect(history.item(id: a.id)?.text == "a")
        #expect(history.remove(id: UUID()) == nil)
        #expect(history.remove(id: a.id)?.id == a.id)
        #expect(history.items.isEmpty)
        #expect(history.item(id: a.id) == nil)
    }

    @Test func togglePin() {
        let a = clip("a")
        var history = ClipHistory(items: [a])
        #expect(history.togglePin(id: a.id) == true)
        #expect(history.item(id: a.id)?.isPinned == true)
        #expect(history.togglePin(id: a.id) == false)
        #expect(history.togglePin(id: UUID()) == nil)
    }

    @Test func clearVariants() {
        let items = [clip("a", at: 1), clip("b", at: 2, pinned: true), clip("c", at: 3)]
        var keep = ClipHistory(items: items)
        #expect(keep.clear(keepPinned: true).compactMap(\.text) == ["c", "a"])
        #expect(keep.items.compactMap(\.text) == ["b"])
        var all = ClipHistory(items: items)
        #expect(all.clear(keepPinned: false).count == 3)
        #expect(all.items.isEmpty)
    }

    @Test func bump() {
        let a = clip("a", at: 1), b = clip("b", at: 2)
        var history = ClipHistory(items: [a, b])
        let bumped = history.bump(id: a.id, at: at(9))
        #expect(bumped?.copyCount == 2)
        #expect(bumped?.lastCopiedAt == at(9))
        #expect(history.items.first?.id == a.id)
        #expect(history.bump(id: UUID(), at: at(10)) == nil)
    }

    @Test func matching() {
        let history = ClipHistory(items: [
            clip("Café Résumé notes", at: 1, source: "Notes"),
            clip("https://example.com/swift", kind: .link, at: 2, source: "Safari"),
            clip("swift build", at: 3, source: "Terminal"),
        ])
        #expect(history.matching(query: "", kind: nil).count == 3)
        #expect(history.matching(query: "  \n ", kind: nil).count == 3)
        #expect(history.matching(query: "SWIFT", kind: nil).compactMap(\.text) == ["swift build", "https://example.com/swift"])
        #expect(history.matching(query: "swift", kind: .link).count == 1)
        #expect(history.matching(query: "cafe resume", kind: nil).count == 1)
        #expect(history.matching(query: "swift terminal", kind: nil).compactMap(\.text) == ["swift build"])
        #expect(history.matching(query: "safari", kind: nil).count == 1)
        #expect(history.matching(query: "swift nothing", kind: nil).isEmpty)
        #expect(history.matching(query: "", kind: .color).isEmpty)
    }

    @Test func counts() {
        let history = ClipHistory(items: [
            clip("a", kind: .text, at: 1), clip("b", kind: .text, at: 2), clip("c", kind: .link, at: 3),
        ])
        #expect(history.count(of: nil) == 3)
        #expect(history.count(of: .text) == 2)
        #expect(history.count(of: .link) == 1)
        #expect(history.count(of: .image) == 0)
    }
}
