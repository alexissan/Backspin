import AppKit
import SwiftUI
import BackspinCore

enum Neon {
    static let night = Color(red: 0.06, green: 0.02, blue: 0.14)
    static let dusk = Color(red: 0.20, green: 0.06, blue: 0.38)
    static let horizon = Color(red: 0.45, green: 0.08, blue: 0.45)
    static let magenta = Color(red: 1.0, green: 0.18, blue: 0.80)
    static let violet = Color(red: 0.62, green: 0.31, blue: 0.95)
    static let cyan = Color(red: 0.10, green: 0.92, blue: 1.0)
    static let lavender = Color(red: 0.84, green: 0.76, blue: 1.0)
    static let sunTop = Color(red: 1.0, green: 0.86, blue: 0.35)

    static let edge = LinearGradient(colors: [magenta, violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let wordmark = LinearGradient(colors: [cyan, lavender, magenta], startPoint: .leading, endPoint: .trailing)
}

/// Every colour and type decision that differs between Classic and Retro lives here,
/// so views describe structure and the palette describes the look.
struct Palette {
    let theme: Theme

    var isRetro: Bool { theme == .retro }

    var primary: Color { isRetro ? .white : .primary }
    var secondary: Color { isRetro ? Neon.lavender.opacity(0.8) : .secondary }
    var faint: Color { isRetro ? Neon.lavender.opacity(0.55) : Color.secondary.opacity(0.75) }
    var header: Color { isRetro ? Neon.cyan : .secondary }
    var headerTracking: CGFloat { isRetro ? 1.6 : 0 }
    var tint: Color { isRetro ? Neon.cyan : .accentColor }
    var accentGlyph: Color { isRetro ? Neon.magenta : .secondary }
    var hairline: Color { isRetro ? Neon.violet.opacity(0.5) : Color.primary.opacity(0.1) }
    var hoverFill: Color { isRetro ? Neon.magenta.opacity(0.16) : Color.primary.opacity(0.06) }
    var tileFill: Color { isRetro ? Neon.night.opacity(0.72) : Color.primary.opacity(0.07) }
    var tileStroke: Color { isRetro ? Neon.violet.opacity(0.7) : Color.primary.opacity(0.06) }
    var tileGlyph: Color { isRetro ? Neon.cyan : .secondary }
    var recording: Color { isRetro ? Neon.magenta : .red }
    var warning: Color { isRetro ? Neon.sunTop : .orange }
    var design: Font.Design { isRetro ? .monospaced : .default }
    var titleWidth: Font.Width { isRetro ? .expanded : .standard }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        // Monospaced glyphs run wide, so Retro sets them a touch smaller to fit the same columns.
        .system(size: isRetro ? (size * 0.93).rounded() : size, weight: weight, design: design)
    }

    var selectionFill: AnyShapeStyle {
        isRetro
            ? AnyShapeStyle(LinearGradient(colors: [Neon.magenta.opacity(0.9), Neon.violet.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.accentColor)
    }

    var chipFill: AnyShapeStyle {
        isRetro
            ? AnyShapeStyle(LinearGradient(colors: [Neon.magenta, Neon.violet], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.accentColor)
    }

    var wordmarkStyle: AnyShapeStyle {
        isRetro ? AnyShapeStyle(Neon.wordmark) : AnyShapeStyle(.primary)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(theme: .classic)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// The raised surface used for the preview and the information table.
struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if palette.isRetro {
            content
                .background(Neon.night.opacity(0.7), in: shape)
                .overlay(shape.strokeBorder(Neon.edge, lineWidth: 1))
                .shadow(color: Neon.magenta.opacity(0.35), radius: 10)
        } else {
            content
                .background(Color.primary.opacity(0.05), in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }
}

extension View {
    func card(cornerRadius: CGFloat = 12) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius))
    }
}

/// A pill with true semicircular ends (the system capsule draws stray edges when stroked at small sizes).
struct Pill: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        return Path(roundedRect: rect, cornerRadius: rect.height / 2, style: .circular)
    }

    func inset(by amount: CGFloat) -> Pill {
        Pill(inset: inset + amount)
    }
}

struct Hairline: View {
    @Environment(\.palette) private var palette
    var vertical = false

    var body: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .accessibilityHidden(true)
    }
}

/// A keyboard key, drawn the way the footer and the shortcut recorder show shortcuts.
struct KeyCap: View {
    @Environment(\.palette) private var palette
    let label: String
    var onSelection = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Text(label)
            .font(.system(size: 11, weight: .medium, design: palette.design))
            .foregroundStyle(foreground)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(stroke, lineWidth: 1))
    }

    private var foreground: Color {
        if onSelection { return .white }
        return palette.isRetro ? Neon.cyan : .secondary
    }

    private var fill: Color {
        if onSelection { return Color.white.opacity(0.18) }
        return palette.isRetro ? Neon.night.opacity(0.6) : Color.primary.opacity(0.06)
    }

    private var stroke: Color {
        if onSelection { return Color.white.opacity(0.35) }
        return palette.isRetro ? Neon.cyan.opacity(0.65) : Color.primary.opacity(0.1)
    }
}

/// Behind-window blur for the Classic panel. The mask keeps the blur inside the rounded corners.
struct VisualEffectBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 18

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.mask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Night sky, striped sun and a neon floor grid. `sunX` places the sun along the width.
struct SynthwaveBackdrop: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var sunX: Double = 0.5
    var horizonY: Double = 0.78
    var maxSunRadius: Double = 110

    private static let stars: [(x: Double, y: Double, size: Double)] = [
        (0.04, 0.07, 1.6), (0.11, 0.20, 1.0), (0.19, 0.05, 1.3), (0.27, 0.15, 0.9),
        (0.34, 0.08, 1.5), (0.42, 0.24, 1.1), (0.47, 0.06, 0.8), (0.55, 0.17, 0.8),
        (0.61, 0.04, 1.2), (0.68, 0.22, 0.9), (0.74, 0.10, 0.7), (0.81, 0.05, 1.4),
        (0.87, 0.19, 1.0), (0.93, 0.09, 1.2), (0.97, 0.26, 0.8), (0.15, 0.34, 0.7),
        (0.38, 0.38, 0.9), (0.58, 0.33, 0.7), (0.90, 0.36, 1.0), (0.24, 0.46, 0.8),
    ]

    var body: some View {
        let dim = contrast == .increased ? 0.4 : 1.0
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Neon.night, Neon.dusk, Neon.horizon]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            for star in Self.stars {
                let r = star.size
                let dot = CGRect(x: star.x * size.width - r / 2, y: star.y * size.height - r / 2, width: r, height: r)
                context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.7 * dim)))
            }

            let horizon = size.height * horizonY
            let sunRadius = min(size.width * 0.24, maxSunRadius)
            let center = CGPoint(x: size.width * sunX, y: horizon)

            context.drawLayer { layer in
                layer.opacity = 0.62 * dim
                layer.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: horizon)))
                let sun = CGRect(x: center.x - sunRadius, y: center.y - sunRadius, width: sunRadius * 2, height: sunRadius * 2)
                layer.fill(Path(ellipseIn: sun), with: .linearGradient(
                    Gradient(colors: [Neon.sunTop, Neon.magenta]),
                    startPoint: CGPoint(x: 0, y: sun.minY),
                    endPoint: CGPoint(x: 0, y: horizon)
                ))
                layer.blendMode = .destinationOut
                var gap: CGFloat = 2
                var y = horizon - sunRadius * 0.55
                while y < horizon {
                    layer.fill(Path(CGRect(x: sun.minX, y: y, width: sun.width, height: gap)), with: .color(.black))
                    y += gap + 6
                    gap += 1.2
                }
            }

            context.drawLayer { layer in
                layer.opacity = 0.5 * dim
                var grid = Path()
                let floor = size.height - horizon
                let spread = max(size.width * 0.12, 60)
                for i in -14...14 {
                    grid.move(to: CGPoint(x: center.x + CGFloat(i) * 6, y: horizon))
                    grid.addLine(to: CGPoint(x: center.x + CGFloat(i) * spread, y: size.height))
                }
                for step in 0...7 {
                    let t = CGFloat(step) / 7
                    let y = horizon + floor * t * t
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                layer.stroke(grid, with: .color(Neon.magenta), lineWidth: 0.8)
            }
        }
        .accessibilityHidden(true)
    }
}
