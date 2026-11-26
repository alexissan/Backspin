import AppKit
import SwiftUI
import BackspinCore

/// Made-up history for `--demo` and the README screenshots. Nothing here is read from the real clipboard.
@MainActor
enum DemoData {
    struct Content {
        var items: [ClipItem]
        var images: [UUID: NSImage]
        var noteID: UUID
        var imageID: UUID
        var codeID: UUID
    }

    static func make(now: Date) -> Content {
        let minute: TimeInterval = 60
        let hour: TimeInterval = 3600
        let day: TimeInterval = 86_400

        func clip(
            _ kind: ClipKind,
            _ text: String,
            ago: TimeInterval,
            from app: (name: String, id: String),
            pinned: Bool = false,
            copies: Int = 1
        ) -> ClipItem {
            ClipItem(
                kind: kind,
                text: text,
                byteCount: text.utf8.count,
                sourceBundleID: app.id,
                sourceName: app.name,
                firstCopiedAt: now.addingTimeInterval(-ago - (copies > 1 ? day : 0)),
                lastCopiedAt: now.addingTimeInterval(-ago),
                copyCount: copies,
                isPinned: pinned,
                contentHash: ContentClassifier.contentHash(text: text)
            )
        }

        let safari = (name: "Safari", id: "com.apple.Safari")
        let notes = (name: "Notes", id: "com.apple.Notes")
        let terminal = (name: "Terminal", id: "com.apple.Terminal")
        let mail = (name: "Mail", id: "com.apple.mail")
        let finder = (name: "Finder", id: "com.apple.finder")
        let preview = (name: "Preview", id: "com.apple.Preview")

        let note = clip(.text, """
            Launch checklist
            • Record the demo with the retro theme on
            • Proofread the Spanish strings
            • One last VoiceOver pass on the panel
            """, ago: 4 * minute, from: notes, copies: 3)

        let code = clip(.text, """
            func spinBack(to clip: Clip) async throws {
                try await pasteboard.write(clip)
                await panel.close()
            }
            """, ago: 38 * minute, from: terminal)

        let picture = renderedImage()
        let image = ClipItem(
            kind: .image,
            imageFile: "demo.png",
            pixelWidth: 1280,
            pixelHeight: 800,
            byteCount: 412_000,
            sourceBundleID: preview.id,
            sourceName: preview.name,
            firstCopiedAt: now.addingTimeInterval(-12 * minute),
            contentHash: "demo-image"
        )

        let items = [
            clip(.link, "https://github.com/alexissan/Backspin", ago: 3 * day, from: safari, pinned: true, copies: 6),
            clip(.text, "hello@example.com", ago: 5 * day, from: mail, pinned: true, copies: 12),
            note,
            image,
            clip(.color, "#FF2DCC", ago: 21 * minute, from: safari),
            code,
            clip(.link, "https://developer.apple.com/design/human-interface-guidelines", ago: 2 * hour, from: safari),
            clip(.text, "Sounds good, let's ship it on Friday.", ago: day + hour, from: mail),
            clip(.color, "rgb(26, 235, 255)", ago: day + 3 * hour, from: safari),
            clip(.file, "/Users/you/Documents/Invoice 2026-11.pdf", ago: day + 5 * hour, from: finder),
            clip(.text, "git log --oneline --graph --decorate", ago: 3 * day, from: terminal, copies: 4),
            clip(.link, "mailto:press@example.com", ago: 4 * day, from: mail),
            clip(.text, "The quick brown fox jumps over the lazy dog.", ago: 12 * day, from: notes),
        ]

        return Content(items: items, images: [image.id: picture], noteID: note.id, imageID: image.id, codeID: code.id)
    }

    private static func renderedImage() -> NSImage {
        let renderer = ImageRenderer(content: SynthwaveBackdrop(maxSunRadius: 150).frame(width: 640, height: 400))
        renderer.scale = 2
        return renderer.nsImage ?? NSImage(size: NSSize(width: 640, height: 400))
    }
}
