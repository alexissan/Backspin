import AppKit
import BackspinCore
import Carbon.HIToolbox

public enum KeyComboFormatter {
    @MainActor
    public static func string(for combo: KeyCombo) -> String {
        parts(for: combo).joined()
    }

    @MainActor
    public static func parts(for combo: KeyCombo) -> [String] {
        var result: [String] = []
        if combo.modifiers.contains(.control) { result.append("⌃") }
        if combo.modifiers.contains(.option) { result.append("⌥") }
        if combo.modifiers.contains(.shift) { result.append("⇧") }
        if combo.modifiers.contains(.command) { result.append("⌘") }
        result.append(keyName(for: combo.keyCode))
        return result
    }

    @MainActor
    public static func combo(from event: NSEvent) -> KeyCombo? {
        guard event.type == .keyDown, !modifierKeyCodes.contains(event.keyCode) else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    public static func carbonModifiers(_ modifiers: KeyCombo.Modifiers) -> UInt32 {
        var mask = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.control) { mask |= controlKey }
        return UInt32(mask)
    }

    /// The unmodified character the current keyboard layout produces for a key code, uppercased.
    @MainActor
    static func layoutCharacter(forKeyCode keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            let string = String(utf16CodeUnits: chars, count: length)
            guard let scalar = string.unicodeScalars.first, scalar.value > 0x20 else { return nil }
            return string.uppercased()
        }
    }

    @MainActor
    private static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] { return special }
        return layoutCharacter(forKeyCode: keyCode) ?? usAnsiKeys[keyCode] ?? "Key \(keyCode)"
    }

    private static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    private static let specialKeys: [UInt32: String] = [
        49: "Space", 36: "↩", 76: "⌤", 48: "⇥", 53: "⎋", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    private static let usAnsiKeys: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".", 50: "`",
    ]
}
