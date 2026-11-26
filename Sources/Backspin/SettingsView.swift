import AppKit
import SwiftUI
import BackspinCore
import BackspinKit

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: ClipStore
    /// Registers a new global shortcut; false when macOS refuses it.
    let applyHotKey: (KeyCombo) -> Bool
    /// Releases the shortcut while a new one is being typed, so it can be typed at all.
    let suspendHotKey: (Bool) -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var trusted = Paster.isTrusted
    @State private var confirmingClear = false

    private static let limits = [100, 250, 500, 1000, 2500]

    var body: some View {
        Form {
            Section("Appearance") {
                ThemePicker(selection: $settings.theme)
            }

            Section {
                LabeledContent("Open Backspin") {
                    ShortcutRecorder(settings: settings, apply: applyHotKey, suspend: suspendHotKey)
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Click the shortcut, then press the keys you want. It needs ⌘, ⌃ or ⌥.")
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                        .accessibilityHidden(true)
                    Text(trusted ? "Backspin can paste for you" : "Return only copies for now")
                    Spacer()
                    if !trusted {
                        Button("Allow…") {
                            Paster.requestTrust()
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("Pasting")
            } footer: {
                Text("To paste straight into the app you were using, Backspin needs Accessibility permission. It is only used to press ⌘V.")
            }

            Section {
                Picker("Keep", selection: $store.historyLimit) {
                    ForEach(Self.limits, id: \.self) { limit in
                        Text("\(limit) clips").tag(limit)
                    }
                }
                Toggle("Pause recording", isOn: $store.isPaused)
                LabeledContent {
                    Button("Clear History…", role: .destructive) { confirmingClear = true }
                        .disabled(store.items.allSatisfy(\.isPinned))
                } label: {
                    Text("\(store.items.count) clips saved")
                }
            } header: {
                Text("History")
            } footer: {
                Text("Pinned clips never count towards the limit. Everything stays on this Mac, and anything a password manager marks as private is never saved.")
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        if !LaunchAtLogin.setEnabled(enabled) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Clear your clipboard history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { store.clear(keepPinned: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned clips are kept. This can't be undone.")
        }
        .task {
            while !Task.isCancelled {
                trusted = Paster.isTrusted
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}

// MARK: - Theme

private struct ThemePicker: View {
    @Binding var selection: Theme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Theme.allCases) { theme in
                ThemeCard(theme: theme, isOn: selection == theme) { selection = theme }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isOn: Bool
    let action: () -> Void

    private var title: LocalizedStringKey { theme == .retro ? "Retro" : "Classic" }
    private var caption: LocalizedStringKey {
        theme == .retro ? "Neon grid, striped sun" : "Follows light and dark"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                swatch
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isOn ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isOn ? 2.5 : 1)
                    )
                HStack(spacing: 5) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                    Text(title).fontWeight(.medium)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(caption)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var swatch: some View {
        if theme == .retro {
            SynthwaveBackdrop(sunX: 0.5, horizonY: 0.72, maxSunRadius: 26)
        } else {
            HStack(spacing: 0) {
                miniature(background: Color(white: 0.95), bar: Color.black.opacity(0.14))
                miniature(background: Color(white: 0.17), bar: Color.white.opacity(0.2))
            }
        }
    }

    private func miniature(background: Color, bar: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(Color.accentColor).frame(width: 46, height: 7)
            Capsule().fill(bar).frame(width: 58, height: 7)
            Capsule().fill(bar).frame(width: 34, height: 7)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(background)
    }
}

// MARK: - Shortcut

private struct ShortcutRecorder: View {
    @Bindable var settings: AppSettings
    let apply: (KeyCombo) -> Bool
    let suspend: (Bool) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var problem: LocalizedStringKey?

    var body: some View {
        HStack(spacing: 8) {
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button {
                recording ? stop() : start()
            } label: {
                HStack(spacing: 3) {
                    if recording {
                        Text("Type shortcut…")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(KeyComboFormatter.parts(for: settings.hotKey), id: \.self) { KeyCap(label: $0) }
                    }
                }
                .padding(.horizontal, 8)
                .frame(minWidth: 96, minHeight: 28)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(recording ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: recording ? 2 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shortcut")
            .accessibilityValue(recording ? Text("Recording") : Text(verbatim: KeyComboFormatter.string(for: settings.hotKey)))
            .accessibilityHint("Press to record a new shortcut. Escape cancels.")

            if settings.hotKey != .standard && !recording {
                Button("Reset") { commit(.standard) }
                    .controlSize(.small)
                    .accessibilityHint(Text(verbatim: KeyComboFormatter.string(for: .standard)))
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        problem = nil
        recording = true
        suspend(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = UInt32(event.keyCode)
            let flags = event.modifierFlags
            MainActor.assumeIsolated { received(keyCode: keyCode, flags: flags) }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if recording {
            recording = false
            suspend(false)
        }
    }

    private func received(keyCode: UInt32, flags: NSEvent.ModifierFlags) {
        if keyCode == 53 {
            stop()
            return
        }
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        guard combo.isUsable else {
            problem = "Add ⌘, ⌃ or ⌥"
            return
        }
        stop()
        commit(combo)
    }

    private func commit(_ combo: KeyCombo) {
        if apply(combo) {
            settings.hotKey = combo
            problem = nil
        } else {
            problem = "That shortcut is taken"
            _ = apply(settings.hotKey)
        }
    }
}
