import Foundation

public struct ClipHistory: Equatable, Sendable {
    public static let defaultLimit = 500

    public private(set) var items: [ClipItem]
    public private(set) var limit: Int

    public init(items: [ClipItem] = [], limit: Int = ClipHistory.defaultLimit) {
        self.items = items.enumerated()
            .sorted { lhs, rhs in
                lhs.element.lastCopiedAt != rhs.element.lastCopiedAt
                    ? lhs.element.lastCopiedAt > rhs.element.lastCopiedAt
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
        self.limit = max(1, limit)
        enforceLimit()
    }

    public struct RecordOutcome: Equatable, Sendable {
        public let item: ClipItem
        public let wasRepeat: Bool
        public let evicted: [ClipItem]
    }

    @discardableResult
    public mutating func record(_ item: ClipItem) -> RecordOutcome {
        if let index = items.firstIndex(where: { $0.contentHash == item.contentHash && $0.kind == item.kind }) {
            var existing = items.remove(at: index)
            existing.copyCount += 1
            existing.lastCopiedAt = item.lastCopiedAt
            if let bundleID = item.sourceBundleID { existing.sourceBundleID = bundleID }
            if let name = item.sourceName { existing.sourceName = name }
            items.insert(existing, at: 0)
            return RecordOutcome(item: existing, wasRepeat: true, evicted: [])
        }
        items.insert(item, at: 0)
        let evicted = enforceLimit()
        return RecordOutcome(item: item, wasRepeat: false, evicted: evicted)
    }

    @discardableResult
    public mutating func bump(id: UUID, at date: Date) -> ClipItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        var existing = items.remove(at: index)
        existing.copyCount += 1
        existing.lastCopiedAt = date
        items.insert(existing, at: 0)
        return existing
    }

    @discardableResult
    public mutating func remove(id: UUID) -> ClipItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    @discardableResult
    public mutating func togglePin(id: UUID) -> Bool? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items[index].isPinned.toggle()
        return items[index].isPinned
    }

    @discardableResult
    public mutating func clear(keepPinned: Bool) -> [ClipItem] {
        let removed = items.filter { !(keepPinned && $0.isPinned) }
        items.removeAll { !(keepPinned && $0.isPinned) }
        return removed
    }

    @discardableResult
    public mutating func setLimit(_ limit: Int) -> [ClipItem] {
        self.limit = max(1, limit)
        return enforceLimit()
    }

    public func item(id: UUID) -> ClipItem? {
        items.first { $0.id == id }
    }

    public func matching(query: String, kind: ClipKind?) -> [ClipItem] {
        let tokens = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return items.filter { item in
            if let kind, item.kind != kind { return false }
            return tokens.allSatisfy { token in
                (item.text?.localizedStandardContains(token) ?? false)
                    || (item.sourceName?.localizedStandardContains(token) ?? false)
            }
        }
    }

    public func count(of kind: ClipKind?) -> Int {
        guard let kind else { return items.count }
        return items.count { $0.kind == kind }
    }

    @discardableResult
    private mutating func enforceLimit() -> [ClipItem] {
        var kept = 0
        var evicted: [ClipItem] = []
        items.removeAll { item in
            guard !item.isPinned else { return false }
            kept += 1
            if kept > limit {
                evicted.append(item)
                return true
            }
            return false
        }
        return evicted
    }
}
