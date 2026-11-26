import Foundation
import Testing
@testable import BackspinCore

@Suite struct ClipSectionTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 0, minute: 30))!
    }

    private func clip(daysAgo: Int, hour: Int = 12, pinned: Bool = false, name: String = "x") -> ClipItem {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let date = calendar.date(byAdding: .hour, value: hour, to: day)!
        return ClipItem(kind: .text, text: name, firstCopiedAt: date, isPinned: pinned, contentHash: name)
    }

    private func bucket(_ item: ClipItem) -> ClipSection.Bucket? {
        ClipSection.sections(for: [item], now: now, calendar: calendar).first?.bucket
    }

    @Test(arguments: [
        (0, ClipSection.Bucket.today), (1, .yesterday), (2, .thisWeek), (6, .thisWeek),
        (7, .thisMonth), (30, .thisMonth), (31, .older), (400, .older),
    ])
    func boundaries(_ days: Int, _ expected: ClipSection.Bucket) {
        #expect(bucket(clip(daysAgo: days)) == expected)
    }

    @Test func calendarDaysNotTwentyFourHourSpans() {
        let justBeforeMidnight = clip(daysAgo: 1, hour: 23)
        #expect(bucket(justBeforeMidnight) == .yesterday)
        let earlyToday = clip(daysAgo: 0, hour: 0)
        #expect(bucket(earlyToday) == .today)
    }

    @Test func futureDatesAreToday() {
        let future = ClipItem(kind: .text, text: "f", firstCopiedAt: now.addingTimeInterval(86_400 * 3), contentHash: "f")
        #expect(bucket(future) == .today)
    }

    @Test func pinnedFirstOrderedAndEmptyOmitted() {
        let items = [
            clip(daysAgo: 0, name: "t1"), clip(daysAgo: 50, pinned: true, name: "p1"),
            clip(daysAgo: 0, name: "t2"), clip(daysAgo: 40, name: "o1"), clip(daysAgo: 1, pinned: true, name: "p2"),
        ]
        let sections = ClipSection.sections(for: items, now: now, calendar: calendar)
        #expect(sections.map(\.bucket) == [.pinned, .today, .older])
        #expect(sections[0].items.compactMap(\.text) == ["p1", "p2"])
        #expect(sections[1].items.compactMap(\.text) == ["t1", "t2"])
        #expect(sections[0].id == .pinned)
    }

    @Test func emptyInput() {
        #expect(ClipSection.sections(for: [], now: now, calendar: calendar).isEmpty)
    }
}
