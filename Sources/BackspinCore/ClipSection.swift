import Foundation

public struct ClipSection: Identifiable, Equatable, Sendable {
    public enum Bucket: String, CaseIterable, Sendable {
        case pinned, today, yesterday, thisWeek, thisMonth, older
    }

    public let bucket: Bucket
    public let items: [ClipItem]
    public var id: Bucket { bucket }

    public static func sections(for items: [ClipItem], now: Date, calendar: Calendar = .current) -> [ClipSection] {
        let today = calendar.startOfDay(for: now)
        var grouped: [Bucket: [ClipItem]] = [:]
        for item in items {
            grouped[bucket(for: item, today: today, calendar: calendar), default: []].append(item)
        }
        return Bucket.allCases.compactMap { bucket in
            grouped[bucket].map { ClipSection(bucket: bucket, items: $0) }
        }
    }

    private static func bucket(for item: ClipItem, today: Date, calendar: Calendar) -> Bucket {
        if item.isPinned { return .pinned }
        let day = calendar.startOfDay(for: item.lastCopiedAt)
        let age = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        switch age {
        case ...0: return .today
        case 1: return .yesterday
        case 2...6: return .thisWeek
        case 7...30: return .thisMonth
        default: return .older
        }
    }
}
