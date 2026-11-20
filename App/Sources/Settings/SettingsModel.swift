import AppKit
import Observation
import ZuntrioCore

/// State behind the settings window. Reads and writes go through
/// `ShortcutController`, which persists and re-registers.
@MainActor
@Observable
final class SettingsModel {
    struct Row: Identifiable, Equatable {
        let action: WindowAction
        var shortcut: String?
        var isEnabled: Bool
        var warning: String?
        var id: WindowAction { action }
    }

    /// Settings sections, in menu order.
    static let sections: [(title: String, actions: [WindowAction])] = [
        ("Position", [.center, .maximize]),
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Corners", [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
        ("Thirds", [.nextThird, .previousThird]),
        ("Size", [.larger, .smaller]),
        ("Displays", [.nextDisplay, .previousDisplay]),
        ("History", [.undo, .redo]),
    ]

    private let shortcuts: ShortcutController
    private let pause: PauseController
    private let monitor: AccessibilityMonitor
    private let updates: UpdateChecker
    private var keyMonitor: Any?

    // Disable shortcuts
    private(set) var pausedUntil: Date?
    private(set) var disabledApps: [PauseSettings.DisabledApp] = []
    var pauseHours = 2

    private(set) var rows: [WindowAction: Row] = [:]
    private(set) var preset: ShortcutPreset = .spectacle
    private(set) var recording: WindowAction?
    /// Message shown under the row that was just edited.
    private(set) var rowMessage: (action: WindowAction, text: String)?
    private(set) var isReadOnly = false
    private(set) var launchAtLogin: LaunchAtLogin.State = .disabled
    private(set) var launchAtLoginError: String?
    private(set) var isTrusted = false
    private(set) var checksForUpdates = false

    init(shortcuts: ShortcutController, pause: PauseController, monitor: AccessibilityMonitor, updates: UpdateChecker) {
        self.shortcuts = shortcuts
        self.pause = pause
        self.monitor = monitor
        self.updates = updates
        reload()
    }

    var version: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(ReleaseInfo.displayVersion) (\(build))"
    }

    func reload() {
        let settings = shortcuts.settings
        preset = settings.preset
        isReadOnly = shortcuts.isReadOnly
        for action in WindowAction.allCases {
            var warning: String?
            if shortcuts.failures[action] != nil {
                warning = "In use by another app. Choose a different shortcut."
            } else if shortcuts.systemConflicts.contains(action) {
                warning = "Also a macOS shortcut (System Settings → Keyboard → Keyboard Shortcuts)."
            }
            rows[action] = Row(
                action: action,
                shortcut: settings.combo(for: action)?.displayString,
                isEnabled: settings.isEnabled(action),
                warning: warning
            )
        }
        launchAtLogin = LaunchAtLogin.state
        checksForUpdates = updates.checksAutomatically
        pausedUntil = pause.isPausedNow ? pause.settings.pausedUntil : nil
        disabledApps = pause.settings.disabledApps
        monitor.refresh()
        isTrusted = monitor.isTrusted
    }

    // MARK: - Shortcuts

    func setChecksForUpdates(_ enabled: Bool) {
        updates.checksAutomatically = enabled
        checksForUpdates = enabled
    }

    func select(_ newPreset: ShortcutPreset) {
        stopRecording()
        shortcuts.select(newPreset)
        rowMessage = nil
        reload()
    }

    func setEnabled(_ enabled: Bool, for action: WindowAction) {
        stopRecording()
        shortcuts.setEnabled(enabled, for: action)
        rowMessage = enabled && !shortcuts.settings.isEnabled(action)
            ? (action, "Its default shortcut is now used by another action. Record a new one.")
            : nil
        reload()
    }

    func restoreDefaults() {
        stopRecording()
        shortcuts.restoreDefaults()
        rowMessage = nil
        reload()
    }

    func toggleRecording(_ action: WindowAction) {
        if recording == action {
            stopRecording()
        } else {
            startRecording(action)
        }
    }

    private func startRecording(_ action: WindowAction) {
        stopRecording()
        recording = action
        rowMessage = nil
        // Zuntrio's own shortcuts reach us as hotkey events; everything else
        // arrives as a normal key press below.
        shortcuts.beginCapture { [weak self] combo in
            Log.settings.info("Recording received a key press (registered shortcut)")
            // Re-registering happens in `record`; do it after the Carbon
            // callback for this hotkey has returned.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.record(combo) }
            }
        }
        // Recording events are logged without the keys pressed.
        Log.settings.info("Recording started for \(action.rawValue, privacy: .public); app active=\(NSApp.isActive), key window=\(NSApp.keyWindow != nil)")
        // Only sees key presses while Zuntrio's settings window is key; the
        // event is consumed so it can't trigger anything else in the app.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return nil
        }
    }

    func stopRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if recording != nil {
            Log.settings.info("Recording stopped")
            recording = nil
            shortcuts.endCapture()
            reload()
        }
    }

    private func handle(_ event: NSEvent) {
        guard let action = recording else { return }
        Log.settings.info("Recording received a key press (key event)")
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let plain = flags.intersection([.command, .option, .control, .shift]).isEmpty

        if plain && event.keyCode == 53 { // Esc: cancel
            stopRecording()
            return
        }
        if plain && (event.keyCode == 51 || event.keyCode == 117) { // ⌫ / ⌦: clear
            stopRecording()
            shortcuts.setEnabled(false, for: action)
            reload()
            return
        }

        var modifiers: ShortcutModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        record(KeyCombo(keyCode: event.keyCode, modifiers: modifiers))
    }

    private func record(_ combo: KeyCombo) {
        guard let action = recording else { return }
        stopRecording()
        if let issue = shortcuts.assign(combo, to: action) {
            Log.settings.info("Recorded shortcut refused: \(String(describing: issue), privacy: .public)")
            rowMessage = (action, Self.describe(issue, combo))
        } else if shortcuts.failures[action] != nil {
            rowMessage = (action, "\(combo.displayString) is in use by another app.")
        }
        reload()
    }

    static func describe(_ issue: ShortcutIssue, _ combo: KeyCombo) -> String {
        switch issue {
        case .needsCommandOrControl: "\(combo.displayString) needs ⌘ or ⌃ so it doesn't interfere with typing."
        case .usedByAction(let other): "\(combo.displayString) is already used by \(other.displayName)."
        case .reservedBySystem: "\(combo.displayString) is a macOS shortcut."
        }
    }

    // MARK: - Disable shortcuts

    var pausedUntilText: String? {
        pausedUntil.map(StatusMenuController.format)
    }

    func pauseNow() {
        pause.pause(hours: pauseHours)
        reload()
    }

    func resume() {
        pause.resume()
        reload()
    }

    func removeDisabledApp(_ bundleID: String) {
        pause.enable(bundleID: bundleID)
        reload()
    }

    /// Lets the person pick an app whose window should never get Zuntrio's shortcuts.
    func addDisabledApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.message = "Zuntrio's shortcuts will be off while this app is in front."
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        pause.disable(PauseSettings.DisabledApp(bundleID: bundleID, name: name))
        reload()
    }

    // MARK: - General

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Couldn't change the login item: \(error.localizedDescription)"
            Log.permissions.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = LaunchAtLogin.state
    }

    func openLoginItemsSettings() {
        LaunchAtLogin.openLoginItemsSettings()
    }

    func openAccessibilitySettings() {
        if !AccessibilityPermission.requestTrustPrompt() {
            AccessibilityPermission.openSystemSettings()
        }
    }
}
