import Foundation

public struct ColorValue: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init?(_ string: String) {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("#") {
            guard let value = Self.parseHex(String(text.dropFirst())) else { return nil }
            self = value
        } else if text.hasSuffix(")"), let open = text.firstIndex(of: "(") {
            let name = text[..<open].trimmingCharacters(in: .whitespaces)
            let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
            let parts = inner.split(whereSeparator: { $0 == "," || $0 == "/" || $0.isWhitespace }).map(String.init)
            guard parts.count == 3 || parts.count == 4 else { return nil }
            switch name {
            case "rgb", "rgba":
                guard let value = Self.parseRGB(parts) else { return nil }
                self = value
            case "hsl", "hsla":
                guard let value = Self.parseHSL(parts) else { return nil }
                self = value
            default:
                return nil
            }
        } else {
            return nil
        }
    }

    public var hex: String {
        let base = String(format: "#%02X%02X%02X", Self.byte(red), Self.byte(green), Self.byte(blue))
        return alpha < 1 ? base + String(format: "%02X", Self.byte(alpha)) : base
    }

    public var rgb: String {
        let channels = "\(Self.byte(red)), \(Self.byte(green)), \(Self.byte(blue))"
        return alpha < 1 ? "rgba(\(channels), \(Self.alphaText(alpha)))" : "rgb(\(channels))"
    }

    public var hsl: String {
        let r = Self.clamp(red), g = Self.clamp(green), b = Self.clamp(blue)
        let high = max(r, g, b), low = min(r, g, b)
        let delta = high - low
        let lightness = (high + low) / 2
        var hue = 0.0
        var saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            if high == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if high == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        let h = Int(hue.rounded()) % 360
        let s = Int((saturation * 100).rounded())
        let l = Int((lightness * 100).rounded())
        return alpha < 1
            ? "hsla(\(h), \(s)%, \(l)%, \(Self.alphaText(alpha)))"
            : "hsl(\(h), \(s)%, \(l)%)"
    }

    public var isLight: Bool {
        func linear(_ value: Double) -> Double {
            let v = Self.clamp(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) > 0.5
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static func byte(_ value: Double) -> Int { Int((clamp(value) * 255).rounded()) }

    private static func alphaText(_ value: Double) -> String {
        var text = String(format: "%.2f", clamp(value))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private static func parseHex(_ digits: String) -> ColorValue? {
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        var expanded = Array(digits)
        if digits.count <= 4 { expanded = expanded.flatMap { [$0, $0] } }
        func component(_ index: Int) -> Double {
            Double(Int(String(expanded[index * 2 ..< index * 2 + 2]), radix: 16) ?? 0) / 255
        }
        return ColorValue(
            red: component(0), green: component(1), blue: component(2),
            alpha: expanded.count == 8 ? component(3) : 1
        )
    }

    private static func number(_ token: String, percentScale: Double) -> Double? {
        if token.hasSuffix("%") {
            return Double(token.dropLast()).map { $0 / 100 }
        }
        return Double(token).map { $0 / percentScale }
    }

    private static func parseAlpha(_ parts: [String]) -> Double? {
        guard parts.count == 4 else { return 1 }
        return number(parts[3], percentScale: 1).map(clamp)
    }

    private static func parseRGB(_ parts: [String]) -> ColorValue? {
        guard
            let r = number(parts[0], percentScale: 255),
            let g = number(parts[1], percentScale: 255),
            let b = number(parts[2], percentScale: 255),
            let a = parseAlpha(parts)
        else { return nil }
        return ColorValue(red: clamp(r), green: clamp(g), blue: clamp(b), alpha: a)
    }

    private static func parseHSL(_ parts: [String]) -> ColorValue? {
        var hueText = parts[0]
        if hueText.hasSuffix("deg") { hueText.removeLast(3) }
        guard
            let hueValue = Double(hueText),
            let s = number(parts[1], percentScale: 100),
            let l = number(parts[2], percentScale: 100),
            let a = parseAlpha(parts)
        else { return nil }
        var hue = hueValue.truncatingRemainder(dividingBy: 360)
        if hue < 0 { hue += 360 }
        let saturation = clamp(s), lightness = clamp(l)
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - chroma / 2
        let (r, g, b): (Double, Double, Double)
        switch hue {
        case ..<60: (r, g, b) = (chroma, x, 0)
        case ..<120: (r, g, b) = (x, chroma, 0)
        case ..<180: (r, g, b) = (0, chroma, x)
        case ..<240: (r, g, b) = (0, x, chroma)
        case ..<300: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        return ColorValue(red: r + m, green: g + m, blue: b + m, alpha: a)
    }
}
