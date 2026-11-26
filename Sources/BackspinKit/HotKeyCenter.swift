import BackspinCore
import Carbon.HIToolbox
import Foundation

@MainActor
public final class HotKeyCenter {
    public static let shared = HotKeyCenter()

    public var handler: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    @discardableResult
    public func register(_ combo: KeyCombo) -> Bool {
        unregister()
        guard installEventHandlerIfNeeded() else { return false }
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4253_504E), id: 1)
        let status = RegisterEventHotKey(
            combo.keyCode,
            KeyComboFormatter.carbonModifiers(combo.modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() -> Bool {
        if eventHandlerRef != nil { return true }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var ref: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { HotKeyCenter.shared.handler?() }
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &ref
        )
        guard status == noErr else { return false }
        eventHandlerRef = ref
        return true
    }
}
