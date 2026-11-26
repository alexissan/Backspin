import AppKit
import Observation
import SwiftUI
import BackspinCore
import BackspinKit

@MainActor @Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var theme: Theme {
        didSet { defaults.set(theme.rawValue, forKey: Theme.storageKey) }
    }

    /// Off hides the menu bar icon; the shortcut still opens the panel.
    var showsMenuBarIcon: Bool {
        didSet { defaults.set(showsMenuBarIcon, forKey: Self.menuBarIconKey) }
    }

    static let menuBarIconKey = "showsMenuBarIcon"

    var hotKey: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: KeyCombo.storageKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = Theme(storedValue: defaults.string(forKey: Theme.storageKey))
        showsMenuBarIcon = defaults.object(forKey: Self.menuBarIconKey) as? Bool ?? true
        hotKey = defaults.data(forKey: KeyCombo.storageKey)
            .flatMap { try? JSONDecoder().decode(KeyCombo.self, from: $0) } ?? .standard
    }
}

enum PasteMode {
    case paste
    case pastePlain
    case copy
}

/// State behind the history panel: what is typed, which kind is filtered, what is selected.
@MainActor @Observable
final class PanelModel {
    static let filters: [ClipKind?] = [nil, .text, .link, .image, .color, .file]

    let store: ClipStore
    let settings: AppSettings

    var query = "" {
        didSet { if query != oldValue { selectedID = nil } }
    }
    var filter: ClipKind? {
        didSet { if filter != oldValue { selectedID = nil } }
    }
    var selectedID: UUID?
    var now = Date()
    /// False until the user lets Backspin send ⌘V for them; Return then only copies.
    var canPaste = true
    /// Bumped each time the panel opens, so the search field can take focus again.
    var presentation = 0

    @ObservationIgnored var perform: (ClipItem, PasteMode) -> Void = { _, _ in }
    @ObservationIgnored var close: () -> Void = {}
    @ObservationIgnored var openSettings: () -> Void = {}
    @ObservationIgnored var allowPasting: () -> Void = {}

    init(store: ClipStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    struct Snapshot {
        var sections: [ClipSection] = []
        var ordered: [ClipItem] = []
        var selected: ClipItem?
        var quickIndex: [UUID: Int] = [:]
    }

    /// One consistent reading of the list for a render or a key press.
    var snapshot: Snapshot {
        let results = store.history.matching(query: query, kind: filter)
        let sections = ClipSection.sections(for: results, now: now)
        let ordered = sections.flatMap(\.items)
        var quick: [UUID: Int] = [:]
        for (offset, item) in ordered.prefix(9).enumerated() {
            quick[item.id] = offset + 1
        }
        let selected = ordered.first { $0.id == selectedID } ?? ordered.first
        return Snapshot(sections: sections, ordered: ordered, selected: selected, quickIndex: quick)
    }

    func prepareForPresentation() {
        query = ""
        filter = nil
        selectedID = nil
        now = Date()
        canPaste = Paster.isTrusted
    }

    /// Call once the panel is the key window; focus requests made before that are dropped.
    func focusSearch() {
        presentation += 1
    }

    func moveSelection(by delta: Int) {
        let snap = snapshot
        guard !snap.ordered.isEmpty else { return }
        let current = snap.selected.flatMap { item in snap.ordered.firstIndex { $0.id == item.id } } ?? 0
        let next = min(max(current + delta, 0), snap.ordered.count - 1)
        selectedID = snap.ordered[next].id
    }

    func cycleFilter(forward: Bool) {
        let all = Self.filters
        let index = all.firstIndex(of: filter) ?? 0
        filter = all[(index + (forward ? 1 : all.count - 1)) % all.count]
    }

    func activateSelection(_ mode: PasteMode) {
        guard let item = snapshot.selected else { return }
        perform(item, mode)
    }

    func activateQuick(_ number: Int) {
        let ordered = snapshot.ordered
        guard ordered.indices.contains(number - 1) else { return }
        perform(ordered[number - 1], .paste)
    }

    func togglePinOnSelection() {
        guard let item = snapshot.selected else { return }
        selectedID = item.id
        store.togglePin(item)
    }

    func deleteSelection() {
        guard let item = snapshot.selected else { return }
        delete(item)
    }

    func delete(_ item: ClipItem) {
        let ordered = snapshot.ordered
        if let index = ordered.firstIndex(where: { $0.id == item.id }), snapshot.selected?.id == item.id {
            let neighbour = ordered.indices.contains(index + 1) ? ordered[index + 1] : (index > 0 ? ordered[index - 1] : nil)
            selectedID = neighbour?.id
        }
        store.delete(item)
    }

    /// Escape clears the search first, then closes.
    func escape() {
        if query.isEmpty {
            close()
        } else {
            query = ""
        }
    }
}

extension ClipKind {
    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "doc"
        }
    }

    var name: String {
        switch self {
        case .text: String(localized: "Text")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        }
    }

    var filterName: String {
        switch self {
        case .text: String(localized: "Text")
        case .link: String(localized: "Links")
        case .color: String(localized: "Colors")
        case .image: String(localized: "Images")
        case .file: String(localized: "Files")
        }
    }
}

extension ClipSection.Bucket {
    var title: String {
        switch self {
        case .pinned: String(localized: "Pinned")
        case .today: String(localized: "Today")
        case .yesterday: String(localized: "Yesterday")
        case .thisWeek: String(localized: "This Week")
        case .thisMonth: String(localized: "This Month")
        case .older: String(localized: "Older")
        }
    }
}

extension ClipItem {
    var pixelSizeText: String? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return "\(pixelWidth) × \(pixelHeight)"
    }

    /// The single line shown in the list.
    var displayTitle: String {
        switch kind {
        case .image:
            [String(localized: "Image"), pixelSizeText].compactMap { $0 }.joined(separator: " · ")
        case .file:
            fileURLs.count > 1 ? "\(summary) +\(fileURLs.count - 1)" : summary
        case .text, .link, .color:
            summary
        }
    }

    var isCode: Bool {
        kind == .text && ContentClassifier.looksLikeCode(text ?? "")
    }

    var tileSymbol: String {
        isCode ? "chevron.left.forwardslash.chevron.right" : kind.symbol
    }

    /// What VoiceOver reads for a row.
    var spokenDescription: String {
        var parts = [kind.name, displayTitle]
        if let sourceName {
            parts.append(String(localized: "from \(sourceName)"))
        }
        parts.append(lastCopiedAt.formatted(.relative(presentation: .named)))
        if isPinned {
            parts.append(String(localized: "Pinned clip"))
        }
        return parts.joined(separator: ", ")
    }
}
