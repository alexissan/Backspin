import AppKit
import SwiftUI
import BackspinCore
import BackspinKit

/// A borderless panel that can take typing without activating Backspin,
/// so the app you were in stays frontmost and can receive the paste.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: PanelModel
    private let panel: KeyPanel
    private var keyMonitor: Any?

    init(model: PanelModel) {
        self.model = model
        panel = KeyPanel(
            contentRect: NSRect(origin: .zero, size: PanelMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.setAccessibilityLabel(String(localized: "Backspin clipboard history"))

        let hosting = NSHostingView(rootView: PanelView(model: model))
        hosting.frame = NSRect(origin: .zero, size: PanelMetrics.size)
        panel.contentView = hosting

        model.close = { [weak self] in self?.hide() }
        model.perform = { [weak self] item, mode in self?.perform(item, mode) }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        model.prepareForPresentation()
        panel.appearance = model.settings.theme == .retro ? NSAppearance(named: .darkAqua) : nil

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = PanelMetrics.size
            panel.setFrame(
                NSRect(
                    x: (visible.midX - size.width / 2).rounded(),
                    y: (visible.midY - size.height / 2 + visible.height * 0.05).rounded(),
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
        }

        installKeyMonitor()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
        panel.invalidateShadow()
        model.focusSearch()
    }

    func hide() {
        removeKeyMonitor()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func perform(_ item: ClipItem, _ mode: PasteMode) {
        model.store.write(item, plainTextOnly: mode == .pastePlain)
        hide()
        guard mode != .copy, Paster.isTrusted else { return }
        Task { @MainActor in
            // Give the previous app a moment to get its key window back.
            try? await Task.sleep(for: .milliseconds(90))
            Paster.pasteIntoFrontmostApp()
        }
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            let handled = MainActor.assumeIsolated {
                guard let self, self.panel.isKeyWindow else { return false }
                return self.handle(keyCode: keyCode, flags: flags)
            }
            return handled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private static let digitKeys: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]

    private func handle(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let modifiers = flags.intersection([.command, .shift, .option, .control])
        let isReturn = keyCode == 36 || keyCode == 76

        if modifiers.isEmpty {
            switch keyCode {
            case 125: model.moveSelection(by: 1)
            case 126: model.moveSelection(by: -1)
            case 121: model.moveSelection(by: 8)
            case 116: model.moveSelection(by: -8)
            case 53: model.escape()
            case 48: model.cycleFilter(forward: true)
            case _ where isReturn: model.activateSelection(model.canPaste ? .paste : .copy)
            default: return false
            }
            return true
        }

        if modifiers == .shift {
            if keyCode == 48 {
                model.cycleFilter(forward: false)
                return true
            }
            if isReturn {
                model.activateSelection(model.canPaste ? .pastePlain : .copy)
                return true
            }
            return false
        }

        if modifiers == .control {
            switch keyCode {
            case 45: model.moveSelection(by: 1)
            case 35: model.moveSelection(by: -1)
            default: return false
            }
            return true
        }

        if modifiers == .command {
            if let number = Self.digitKeys[keyCode] {
                model.activateQuick(number)
                return true
            }
            switch keyCode {
            case _ where isReturn: model.activateSelection(.copy)
            case 35: model.togglePinOnSelection()
            case 51: model.deleteSelection()
            case 43: model.openSettings()
            default: return false
            }
            return true
        }

        return false
    }
}
