import AppKit
import SwiftUI
import BackspinCore
import BackspinKit

private final class ActiveWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { true }
}

/// Renders the README images from demo data: `Backspin --screenshots docs`.
@MainActor
enum ScreenshotRenderer {
    static func run(into directory: String) {
        let dir = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let suite = "dev.alexissantos.backspin.screenshots"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        let content = DemoData.make(now: Date())
        let store = ClipStore(previewItems: content.items, images: content.images)
        let settings = AppSettings(defaults: defaults)

        let shots: [(name: String, appearance: NSAppearance.Name, theme: Theme, selection: UUID)] = [
            ("panel-light", .aqua, .classic, content.noteID),
            ("panel-dark", .darkAqua, .classic, content.imageID),
            ("panel-retro", .darkAqua, .retro, content.codeID),
        ]
        for shot in shots {
            settings.theme = shot.theme
            let model = PanelModel(store: store, settings: settings)
            model.selectedID = shot.selection
            let view = PanelView(model: model, flatBackdrop: true)
                .padding(28)
            write(view, appearance: shot.appearance, to: dir.appendingPathComponent("\(shot.name).png"))
        }

        let settingsView = SettingsView(settings: settings, store: store, applyHotKey: { _ in true }, suspendHotKey: { _ in })
            .background(Color(nsColor: .windowBackgroundColor))
        write(settingsView, appearance: .aqua, to: dir.appendingPathComponent("settings.png"))

        if CommandLine.arguments.contains("--icon") {
            write(AppIconArtwork().frame(width: 1024, height: 1024), appearance: .darkAqua, scale: 1, to: dir.appendingPathComponent("icon-1024.png"))
        }
    }

    private static func write<V: View>(_ view: V, appearance: NSAppearance.Name, scale: CGFloat = 2, to url: URL) {
        let dark = appearance == .darkAqua
        let hosting = NSHostingView(
            rootView: view
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.controlActiveState, .key)
        )
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = ActiveWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        hosting.layoutSubtreeIfNeeded()

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
        window.orderOut(nil)
    }
}

/// The app icon: the striped sun as a record, with an arrow spinning it backwards.
struct AppIconArtwork: View {
    var body: some View {
        Canvas { context, size in
            let inset = size.width * 0.098
            let tile = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let shape = Path(roundedRect: tile, cornerRadius: tile.width * 0.225, style: .continuous)

            context.drawLayer { layer in
                layer.clip(to: shape)
                layer.fill(Path(tile), with: .linearGradient(
                    Gradient(colors: [Neon.night, Neon.dusk, Neon.horizon]),
                    startPoint: CGPoint(x: 0, y: tile.minY),
                    endPoint: CGPoint(x: 0, y: tile.maxY)
                ))

                let horizon = tile.minY + tile.height * 0.70
                let center = CGPoint(x: tile.midX, y: horizon)
                let floor = tile.maxY - horizon
                var grid = Path()
                for i in -9...9 {
                    grid.move(to: CGPoint(x: center.x + CGFloat(i) * 10, y: horizon))
                    grid.addLine(to: CGPoint(x: center.x + CGFloat(i) * tile.width * 0.16, y: tile.maxY))
                }
                for step in 0...6 {
                    let t = CGFloat(step) / 6
                    let y = horizon + floor * t * t
                    grid.move(to: CGPoint(x: tile.minX, y: y))
                    grid.addLine(to: CGPoint(x: tile.maxX, y: y))
                }
                layer.stroke(grid, with: .color(Neon.magenta.opacity(0.75)), lineWidth: size.width * 0.004)

                let radius = tile.width * 0.27
                let sunCenter = CGPoint(x: tile.midX, y: tile.minY + tile.height * 0.47)
                let sun = CGRect(x: sunCenter.x - radius, y: sunCenter.y - radius, width: radius * 2, height: radius * 2)
                layer.drawLayer { disc in
                    disc.fill(Path(ellipseIn: sun), with: .linearGradient(
                        Gradient(colors: [Neon.sunTop, Neon.magenta]),
                        startPoint: CGPoint(x: 0, y: sun.minY),
                        endPoint: CGPoint(x: 0, y: sun.maxY)
                    ))
                    disc.blendMode = .destinationOut
                    var gap = size.width * 0.008
                    var y = sunCenter.y + radius * 0.05
                    while y < sun.maxY {
                        disc.fill(Path(CGRect(x: sun.minX, y: y, width: sun.width, height: gap)), with: .color(.black))
                        y += gap + size.width * 0.03
                        gap += size.width * 0.006
                    }
                }

                let ring = radius * 1.32
                let lineWidth = size.width * 0.036
                var arc = Path()
                arc.addArc(center: sunCenter, radius: ring, startAngle: .degrees(-50), endAngle: .degrees(205), clockwise: false)
                let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                layer.drawLayer { glow in
                    // Mirrored so the arrow runs anticlockwise: a backspin.
                    glow.translateBy(x: sunCenter.x * 2, y: 0)
                    glow.scaleBy(x: -1, y: 1)
                    glow.addFilter(.shadow(color: Neon.cyan.opacity(0.9), radius: size.width * 0.02))
                    glow.stroke(arc, with: .color(Neon.cyan), style: style)

                    let tipAngle = Angle.degrees(205).radians
                    let tip = CGPoint(x: sunCenter.x + ring * cos(tipAngle), y: sunCenter.y + ring * sin(tipAngle))
                    let head = lineWidth * 2.1
                    let direction = tipAngle + .pi / 2
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: tip.x + head * cos(direction), y: tip.y + head * sin(direction)))
                    arrow.addLine(to: CGPoint(x: tip.x + head * 0.85 * cos(direction + 2.3), y: tip.y + head * 0.85 * sin(direction + 2.3)))
                    arrow.addLine(to: CGPoint(x: tip.x + head * 0.85 * cos(direction - 2.3), y: tip.y + head * 0.85 * sin(direction - 2.3)))
                    arrow.closeSubpath()
                    glow.fill(arrow, with: .color(Neon.cyan))
                }
            }
        }
    }
}
