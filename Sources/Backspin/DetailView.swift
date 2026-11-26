import AppKit
import SwiftUI
import BackspinCore
import BackspinKit

/// The right-hand side of the panel: a preview of the selected clip and what is known about it.
struct DetailView: View {
    @Environment(\.palette) private var palette
    let item: ClipItem?
    let store: ClipStore
    let isEmptyHistory: Bool
    let hotKey: KeyCombo

    var body: some View {
        if let item {
            VStack(spacing: 12) {
                ClipPreview(item: item, store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .card()
                InfoTable(item: item)
            }
            .padding(14)
            .id(item.id)
        } else if isEmptyHistory {
            Welcome(hotKey: hotKey)
        } else {
            Color.clear
        }
    }
}

private struct Welcome: View {
    @Environment(\.palette) private var palette
    let hotKey: KeyCombo

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(palette.isRetro ? AnyShapeStyle(Neon.wordmark) : AnyShapeStyle(palette.tint))
                .accessibilityHidden(true)
            Text("Copy something to get started")
                .font(palette.font(16, .semibold))
            Text("Everything you copy lands here. Spin back to it any time with")
                .font(palette.font(12))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 3) {
                ForEach(KeyComboFormatter.parts(for: hotKey), id: \.self) { KeyCap(label: $0) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: KeyComboFormatter.string(for: hotKey)))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

private struct ClipPreview: View {
    @Environment(\.palette) private var palette
    let item: ClipItem
    let store: ClipStore

    /// Enough to recognise a clip without laying out megabytes of text.
    private static let previewLimit = 20_000

    var body: some View {
        switch item.kind {
        case .text:
            ScrollView {
                Text(verbatim: String((item.text ?? "").prefix(Self.previewLimit)))
                    .font(item.isCode || palette.isRetro ? .system(size: 12, design: .monospaced) : .system(size: 13))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
            }
        case .link:
            LinkPreview(text: item.text ?? "")
        case .color:
            ColorPreview(text: item.text ?? "")
        case .image:
            if let image = store.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(12)
                    .accessibilityLabel(Text("Image preview"))
            } else {
                Placeholder(symbol: "photo")
            }
        case .file:
            FilePreview(urls: item.fileURLs)
        }
    }
}

private struct Placeholder: View {
    @Environment(\.palette) private var palette
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(palette.faint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

private struct LinkPreview: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        let url = ContentClassifier.url(in: text)
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: url?.scheme == "mailto" ? "envelope" : "globe")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(palette.tint)
                .accessibilityHidden(true)
            Text(verbatim: title(for: url))
                .font(palette.font(20, .semibold))
                .fontWidth(palette.titleWidth)
                .lineLimit(2)
            Text(verbatim: text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.secondary)
                .lineLimit(5)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            if let url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open Link", systemImage: "arrow.up.right")
                        .font(palette.font(12, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.tint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func title(for url: URL?) -> String {
        guard let url else { return text }
        if url.scheme == "mailto" {
            return String(url.absoluteString.dropFirst("mailto:".count).prefix { $0 != "?" })
        }
        let host = url.host() ?? text
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

private struct ColorPreview: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        if let value = ColorValue(text) {
            ZStack {
                Checkerboard()
                Color(value)
                Text(verbatim: value.hex)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(value.isLight || value.alpha < 0.5 ? Color.black.opacity(0.8) : Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Color swatch, \(value.hex)"))
        } else {
            Placeholder(symbol: "paintpalette")
        }
    }
}

/// Shows through translucent colours, the way image editors do.
private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 10
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var path = Path()
            for row in 0...Int(size.height / cell) {
                for column in 0...Int(size.width / cell) where (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
            context.fill(path, with: .color(Color(white: 0.82)))
        }
    }
}

private struct FilePreview: View {
    @Environment(\.palette) private var palette
    let urls: [URL]

    var body: some View {
        if urls.count == 1, let url = urls.first {
            VStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text(verbatim: url.lastPathComponent)
                    .font(palette.font(14, .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(verbatim: (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                    .font(palette.font(11))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(urls, id: \.self) { url in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                            Text(verbatim: url.lastPathComponent)
                                .font(palette.font(13))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }
}

// MARK: - Information

private struct InfoTable: View {
    @Environment(\.palette) private var palette
    let item: ClipItem

    private struct Row: Identifiable {
        let id: String
        let label: LocalizedStringKey
        let value: String
        var appBundleID: String?
        var monospaced = false
    }

    private var rows: [Row] {
        var rows = [
            Row(id: "source", label: "Source", value: item.sourceName ?? String(localized: "Unknown"), appBundleID: item.sourceBundleID),
        ]
        switch item.kind {
        case .text, .link:
            let stats = TextStats(item.text ?? "")
            rows.append(Row(id: "content", label: "Content", value: [
                item.kind == .link ? item.kind.name : (item.isCode ? String(localized: "Code") : item.kind.name),
                String(localized: "\(stats.characters) characters"),
                String(localized: "\(stats.words) words"),
                String(localized: "\(stats.lines) lines"),
            ].joined(separator: " · ")))
        case .color:
            if let value = ColorValue(item.text ?? "") {
                rows.append(Row(id: "hex", label: "HEX", value: value.hex, monospaced: true))
                rows.append(Row(id: "rgb", label: "RGB", value: value.rgb, monospaced: true))
                rows.append(Row(id: "hsl", label: "HSL", value: value.hsl, monospaced: true))
            }
        case .image:
            rows.append(Row(id: "content", label: "Content", value: [
                item.kind.name,
                item.pixelSizeText,
                item.byteCount.formatted(.byteCount(style: .file)),
            ].compactMap { $0 }.joined(separator: " · ")))
        case .file:
            rows.append(Row(id: "content", label: "Content", value: [
                String(localized: "\(item.fileURLs.count) files"),
                item.byteCount > 0 ? item.byteCount.formatted(.byteCount(style: .file)) : nil,
            ].compactMap { $0 }.joined(separator: " · ")))
        }
        rows.append(Row(id: "copied", label: "Copied", value: item.lastCopiedAt.formatted(date: .abbreviated, time: .shortened)))
        if item.copyCount > 1 {
            rows.append(Row(id: "count", label: "Times copied", value: item.copyCount.formatted()))
        }
        return rows
    }

    var body: some View {
        let rows = rows
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    Text(row.label)
                        .foregroundStyle(palette.secondary)
                    Spacer(minLength: 12)
                    if let icon = AppIcons.icon(forBundleID: row.appBundleID) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: row.value)
                        .font(row.monospaced ? .system(size: 12, design: .monospaced) : palette.font(12))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .font(palette.font(12))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .accessibilityElement(children: .combine)
                if index < rows.count - 1 {
                    Hairline().padding(.leading, 12)
                }
            }
        }
        .card(cornerRadius: 10)
    }
}
