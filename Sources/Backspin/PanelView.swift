import AppKit
import SwiftUI
import BackspinCore
import BackspinKit

enum PanelMetrics {
    static let size = CGSize(width: 820, height: 560)
    static let cornerRadius: CGFloat = 18
    static let listWidth: CGFloat = 318
}

struct PanelView: View {
    @Bindable var model: PanelModel
    /// Screenshots can't capture behind-window blur, so they ask for a flat backdrop.
    var flatBackdrop = false

    var body: some View {
        let palette = Palette(theme: model.settings.theme)
        let snapshot = model.snapshot
        let shape = RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            SearchBar(model: model)
            FilterStrip(model: model)
            Hairline()
            HStack(spacing: 0) {
                ClipList(model: model, snapshot: snapshot)
                    .frame(width: PanelMetrics.listWidth)
                Hairline(vertical: true)
                DetailView(item: snapshot.selected, store: model.store, isEmptyHistory: model.store.items.isEmpty, hotKey: model.settings.hotKey)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Hairline()
            FooterBar(model: model, hasSelection: snapshot.selected != nil)
        }
        .frame(width: PanelMetrics.size.width, height: PanelMetrics.size.height)
        .background { PanelBackdrop(flat: flatBackdrop) }
        .clipShape(shape)
        .overlay {
            if palette.isRetro {
                shape.strokeBorder(Neon.edge, lineWidth: 1)
            } else {
                shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .environment(\.palette, palette)
        .font(palette.font(13))
        .foregroundStyle(palette.primary)
        .tint(palette.tint)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Backspin clipboard history")
    }
}

private struct PanelBackdrop: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme
    let flat: Bool

    var body: some View {
        if palette.isRetro {
            ZStack {
                SynthwaveBackdrop(sunX: 0.7, horizonY: 0.8)
                Neon.night.opacity(0.28)
            }
        } else if flat {
            Color(nsColor: colorScheme == .dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.955, alpha: 1))
        } else {
            ZStack {
                VisualEffectBackground()
                // Blur alone lets busy windows show through; a wash of the window colour keeps text legible.
                Color(nsColor: .windowBackgroundColor).opacity(0.55)
            }
        }
    }
}

// MARK: - Search

private struct SearchBar: View {
    @Environment(\.palette) private var palette
    @Bindable var model: PanelModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.accentGlyph)
                .accessibilityHidden(true)
            TextField("Search your clipboard", text: $model.query)
                .textFieldStyle(.plain)
                .font(palette.font(19))
                .focused($focused)
                .accessibilityLabel("Search your clipboard")
            RecordingToggle(store: model.store)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .onAppear { focused = true }
        .onChange(of: model.presentation) { focused = true }
    }
}

/// A tape-deck style light: lit while Backspin is saving what you copy.
private struct RecordingToggle: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var store: ClipStore
    @State private var pulse = false

    var body: some View {
        Button {
            store.isPaused.toggle()
        } label: {
            HStack(spacing: 6) {
                if store.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.warning)
                } else {
                    Circle()
                        .fill(palette.recording)
                        .frame(width: 8, height: 8)
                        .shadow(color: palette.recording.opacity(palette.isRetro ? 0.9 : 0), radius: 4)
                        .opacity(pulse ? 0.45 : 1)
                }
                Text(store.isPaused ? "Paused" : "Recording")
                    .font(palette.font(11, .semibold))
                    .textCase(palette.isRetro ? .uppercase : nil)
                    .tracking(palette.isRetro ? 1.2 : 0)
                    .foregroundStyle(store.isPaused ? palette.warning : palette.secondary)
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(palette.tileFill, in: Pill())
            .overlay(Pill().strokeBorder(palette.tileStroke, lineWidth: 1))
            .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .help(store.isPaused ? "Resume saving what you copy" : "Pause saving what you copy")
        .accessibilityLabel("Clipboard recording")
        .accessibilityValue(store.isPaused ? "Paused" : "On")
        .accessibilityHint("Pauses or resumes saving what you copy")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - Filters

private struct FilterStrip: View {
    @Environment(\.palette) private var palette
    @Bindable var model: PanelModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PanelModel.filters, id: \.self) { kind in
                FilterChip(
                    title: kind?.filterName ?? String(localized: "All"),
                    symbol: kind?.symbol ?? "square.stack",
                    count: model.store.history.count(of: kind),
                    isOn: model.filter == kind
                ) {
                    model.filter = kind
                }
            }
            Spacer(minLength: 8)
            KeyCap(label: "⇥")
                .accessibilityHidden(true)
                .help("Press Tab to switch between kinds")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by kind")
    }
}

private struct FilterChip: View {
    @Environment(\.palette) private var palette
    let title: String
    let symbol: String
    let count: Int
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(palette.font(12, .medium))
                Text(count, format: .number)
                    .font(palette.font(11))
                    .monospacedDigit()
                    .opacity(0.7)
            }
            .foregroundStyle(isOn ? Color.white : palette.secondary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background {
                if isOn {
                    Pill().fill(palette.chipFill)
                } else {
                    Pill().fill(hovering ? palette.hoverFill : palette.tileFill)
                }
            }
            .overlay {
                if palette.isRetro {
                    Pill().strokeBorder(isOn ? Neon.cyan : Neon.violet.opacity(0.6), lineWidth: 1)
                }
            }
            .contentShape(Pill())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(Text("\(count) clips"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - List

private struct ClipList: View {
    @Environment(\.palette) private var palette
    @Bindable var model: PanelModel
    let snapshot: PanelModel.Snapshot

    var body: some View {
        if snapshot.ordered.isEmpty {
            EmptyList(isSearching: !model.query.isEmpty || model.filter != nil)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(snapshot.sections) { section in
                            SectionHeader(title: section.bucket.title)
                            ForEach(section.items) { item in
                                ClipRow(
                                    item: item,
                                    isSelected: item.id == snapshot.selected?.id,
                                    quickNumber: snapshot.quickIndex[item.id],
                                    model: model
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: snapshot.selected?.id) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    @Environment(\.palette) private var palette
    let title: String

    var body: some View {
        Text(title)
            .font(palette.font(palette.isRetro ? 10 : 11, .semibold))
            .textCase(palette.isRetro ? .uppercase : nil)
            .tracking(palette.headerTracking)
            .foregroundStyle(palette.header)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct EmptyList: View {
    @Environment(\.palette) private var palette
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isSearching ? "magnifyingglass" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(palette.faint)
                .accessibilityHidden(true)
            Text(isSearching ? "No matches" : "Nothing copied yet")
                .font(palette.font(13, .medium))
                .foregroundStyle(palette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct ClipRow: View {
    @Environment(\.palette) private var palette
    let item: ClipItem
    let isSelected: Bool
    let quickNumber: Int?
    let model: PanelModel
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 10) {
            ClipTile(item: item, store: model.store, side: 28, onSelection: isSelected)
            Text(item.displayTitle)
                .font(palette.font(13, isSelected ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.white : palette.primary)
            Spacer(minLength: 4)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : palette.faint)
                    .accessibilityHidden(true)
            }
            if let quickNumber {
                KeyCap(label: "⌘\(quickNumber)", onSelection: isSelected)
                    .opacity(isSelected || hovering ? 1 : 0.55)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background {
            if isSelected {
                shape.fill(palette.selectionFill)
                    .shadow(color: palette.isRetro ? Neon.magenta.opacity(0.55) : .clear, radius: 8)
            } else if hovering {
                shape.fill(palette.hoverFill)
            }
        }
        .overlay {
            if isSelected && palette.isRetro {
                shape.strokeBorder(Neon.cyan, lineWidth: 1)
            }
        }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.perform(item, .paste) }
        .simultaneousGesture(TapGesture().onEnded { model.selectedID = item.id })
        .contextMenu { ClipActions(item: item, model: model) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.spokenDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(model.canPaste ? "Pastes into the app you were using" : "Copies to the clipboard")
        .accessibilityAction { model.perform(item, .paste) }
        .accessibilityAction(named: "Copy") { model.perform(item, .copy) }
        .accessibilityAction(named: item.isPinned ? "Unpin" : "Pin") { model.store.togglePin(item) }
        .accessibilityAction(named: "Delete") { model.delete(item) }
    }
}

/// The same actions the keyboard offers, for the context menu.
private struct ClipActions: View {
    let item: ClipItem
    let model: PanelModel

    var body: some View {
        if model.canPaste {
            Button("Paste") { model.perform(item, .paste) }
            if item.richTextFile != nil {
                Button("Paste as Plain Text") { model.perform(item, .pastePlain) }
            }
        }
        Button("Copy") { model.perform(item, .copy) }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { model.store.togglePin(item) }
        Button("Delete", role: .destructive) { model.delete(item) }
    }
}

/// The square at the start of a row: a thumbnail, a colour swatch, a file icon or a glyph.
struct ClipTile: View {
    @Environment(\.palette) private var palette
    let item: ClipItem
    let store: ClipStore
    let side: CGFloat
    var onSelection = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
        Group {
            if item.kind == .image, let thumbnail = store.thumbnail(for: item, side: side) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else if item.kind == .color, let color = ColorValue(item.text ?? "") {
                Color(color)
            } else if item.kind == .file, let url = item.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else {
                Image(systemName: item.tileSymbol)
                    .font(.system(size: side * 0.42, weight: .medium))
                    .foregroundStyle(onSelection ? Color.white : palette.tileGlyph)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(onSelection ? Color.white.opacity(0.2) : palette.tileFill)
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(onSelection ? Color.white.opacity(0.3) : palette.tileStroke, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

extension Color {
    init(_ value: ColorValue) {
        self.init(.sRGB, red: value.red, green: value.green, blue: value.blue, opacity: value.alpha)
    }
}

// MARK: - Footer

private struct FooterBar: View {
    @Environment(\.palette) private var palette
    @Bindable var model: PanelModel
    let hasSelection: Bool

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.isRetro ? Neon.magenta : palette.tint)
                    .accessibilityHidden(true)
                Text(verbatim: "Backspin")
                    .font(.system(size: 13, weight: palette.isRetro ? .heavy : .semibold, design: palette.design))
                    .fontWidth(palette.titleWidth)
                    .textCase(palette.isRetro ? .uppercase : nil)
                    .foregroundStyle(palette.wordmarkStyle)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            if !model.canPaste {
                Button {
                    model.allowPasting()
                } label: {
                    Label("Allow Pasting…", systemImage: "exclamationmark.triangle.fill")
                        .font(palette.font(12, .medium))
                        .foregroundStyle(palette.warning)
                }
                .buttonStyle(.plain)
                .help("Backspin needs Accessibility permission to paste for you. Until then, Return copies.")
            }

            if hasSelection {
                if model.canPaste {
                    KeyHint(title: "Paste", keys: ["↩"]) { model.activateSelection(.paste) }
                    KeyHint(title: "Copy", keys: ["⌘", "↩"]) { model.activateSelection(.copy) }
                    KeyHint(title: "Plain", keys: ["⇧", "↩"]) { model.activateSelection(.pastePlain) }
                } else {
                    KeyHint(title: "Copy", keys: ["↩"]) { model.activateSelection(.copy) }
                }
                KeyHint(title: "Pin", keys: ["⌘", "P"]) { model.togglePinOnSelection() }
                KeyHint(title: "Delete", keys: ["⌘", "⌫"]) { model.deleteSelection() }
            }

            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(palette.isRetro ? Neon.night.opacity(0.55) : Color.primary.opacity(0.035))
    }
}

private struct KeyHint: View {
    @Environment(\.palette) private var palette
    let title: LocalizedStringKey
    let keys: [String]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(palette.font(12, .medium))
                    .foregroundStyle(palette.secondary)
                HStack(spacing: 2) {
                    ForEach(keys, id: \.self) { KeyCap(label: $0) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(Text(verbatim: keys.joined()))
    }
}
