import Foundation

/// What a clip is, as far as the interface is concerned.
public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text
    case link
    case color
    case image
    case file
}

/// One entry in the clipboard history.
public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    /// The copied string for text, links and colours. Newline-separated paths for files. `nil` for images.
    public var text: String?
    /// File name of the PNG inside the store's blob directory, for images.
    public var imageFile: String?
    /// File name of the RTF data inside the store's blob directory, when the copy carried formatting.
    public var richTextFile: String?
    /// Pixel size, for images.
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    /// Size of the copied payload in bytes.
    public var byteCount: Int
    /// The app that was frontmost when the copy happened.
    public var sourceBundleID: String?
    public var sourceName: String?
    public var firstCopiedAt: Date
    public var lastCopiedAt: Date
    public var copyCount: Int
    public var isPinned: Bool
    /// Stable digest of the content, used to recognise a repeated copy.
    public var contentHash: String

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        text: String? = nil,
        imageFile: String? = nil,
        richTextFile: String? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteCount: Int = 0,
        sourceBundleID: String? = nil,
        sourceName: String? = nil,
        firstCopiedAt: Date = Date(),
        lastCopiedAt: Date? = nil,
        copyCount: Int = 1,
        isPinned: Bool = false,
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFile = imageFile
        self.richTextFile = richTextFile
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.sourceBundleID = sourceBundleID
        self.sourceName = sourceName
        self.firstCopiedAt = firstCopiedAt
        self.lastCopiedAt = lastCopiedAt ?? firstCopiedAt
        self.copyCount = copyCount
        self.isPinned = isPinned
        self.contentHash = contentHash
    }
}

public enum Theme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case retro

    public static let storageKey = "theme"

    public var id: String { rawValue }

    public init(storedValue: String?) {
        self = storedValue.flatMap(Theme.init(rawValue:)) ?? .classic
    }
}

/// A global keyboard shortcut: a virtual key code plus modifiers.
public struct KeyCombo: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let shift = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public static let storageKey = "hotKey"

    /// ⇧⌘V
    public static let standard = KeyCombo(keyCode: 9, modifiers: [.command, .shift])

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A global shortcut needs ⌘, ⌃ or ⌥; ⇧ alone would swallow ordinary typing.
    public var isUsable: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }
}
