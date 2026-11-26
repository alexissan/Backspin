import ApplicationServices
import AppKit
import Carbon.HIToolbox

@MainActor
public enum Paster {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    public static func requestTrust() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    public static func pasteIntoFrontmostApp() -> Bool {
        guard isTrusted else { return false }
        let keyCode = CGKeyCode(vKeyCode())
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func vKeyCode() -> UInt32 {
        for code in UInt32(0)..<128 where KeyComboFormatter.layoutCharacter(forKeyCode: code) == "V" {
            return code
        }
        return 9
    }
}
