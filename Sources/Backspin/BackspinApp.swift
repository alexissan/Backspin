import AppKit
import Observation
import SwiftUI
import BackspinCore
import BackspinKit

@main
enum BackspinMain {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--screenshots"), arguments.indices.contains(index + 1) {
            ScreenshotRenderer.run(into: arguments[index + 1])
            return
        }

        let app = NSApplication.shared
        // `--launch-at-login on|off` flips the login item from a script, then exits.
        if let index = arguments.firstIndex(of: "--launch-at-login"), arguments.indices.contains(index + 1) {
            let succeeded = LaunchAtLogin.setEnabled(arguments[index + 1] == "on")
            print(LaunchAtLogin.isEnabled ? "Launch at login is on" : "Launch at login is off")
            exit(succeeded ? 0 : 1)
        }

        // `--store <folder>` keeps history somewhere else, for trying things without touching the real one.
        let storeDirectory = arguments.firstIndex(of: "--store")
            .flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        let delegate = AppDelegate(demo: arguments.contains("--demo"), storeDirectory: storeDirectory)
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let demo: Bool
    private let storeDirectory: URL?
    private let settings = AppSettings()
    private var store: ClipStore!
    private var model: PanelModel!
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    init(demo: Bool, storeDirectory: URL?) {
        self.demo = demo
        self.storeDirectory = storeDirectory
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if demo {
            let content = DemoData.make(now: Date())
            store = ClipStore(previewItems: content.items, images: content.images)
        } else {
            store = ClipStore(directory: storeDirectory ?? ClipStore.defaultDirectory)
            store.startMonitoring()
        }

        model = PanelModel(store: store, settings: settings)
        panelController = PanelController(model: model)
        model.openSettings = { [weak self] in self?.openSettings() }
        model.allowPasting = { [weak self] in
            self?.panelController.hide()
            Paster.requestTrust()
        }

        HotKeyCenter.shared.handler = { [weak self] in self?.panelController.toggle() }
        HotKeyCenter.shared.register(settings.hotKey)

        installStatusItem()
        observePause()

        let firstLaunchKey = "hasLaunchedBefore"
        if demo || !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            panelController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    // MARK: Menu bar

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.counterclockwise.circle", accessibilityDescription: "Backspin")
        statusItem.button?.setAccessibilityLabel("Backspin")

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshStatusIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(title: String(localized: "Open Backspin"), action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let hint = NSMenuItem(title: KeyComboFormatter.string(for: settings.hotKey), action: nil, keyEquivalent: "")
        hint.isEnabled = false
        hint.indentationLevel = 1
        hint.setAccessibilityLabel(String(localized: "Shortcut"))
        menu.addItem(hint)

        menu.addItem(.separator())
        let pause = NSMenuItem(title: String(localized: "Pause Recording"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = store.isPaused ? .on : .off
        menu.addItem(pause)

        menu.addItem(.separator())
        let preferences = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Backspin"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func refreshStatusIcon() {
        statusItem.button?.appearsDisabled = store.isPaused
        statusItem.button?.toolTip = store.isPaused
            ? String(localized: "Backspin is paused")
            : String(localized: "Backspin is saving what you copy")
    }

    private func observePause() {
        withObservationTracking {
            _ = store.isPaused
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refreshStatusIcon()
                self?.observePause()
            }
        }
    }

    @objc private func openPanel() {
        panelController.show()
    }

    @objc private func togglePause() {
        store.isPaused.toggle()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    // MARK: Settings

    private func openSettings() {
        panelController.hide()
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settings,
                store: store,
                applyHotKey: { HotKeyCenter.shared.register($0) },
                suspendHotKey: { [settings] suspended in
                    if suspended {
                        HotKeyCenter.shared.unregister()
                    } else {
                        HotKeyCenter.shared.register(settings.hotKey)
                    }
                }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Backspin Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
