import AppKit
import Carbon.HIToolbox
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let failures = registerDefaultShortcuts()
        statusMenu = StatusMenuController(runner: runner, shortcuts: DefaultShortcuts.spectacle, unavailable: failures)

        if !AccessibilityPermission.isTrusted {
            Log.permissions.info("Accessibility not granted at launch")
        }

        #if DEBUG
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }

    /// Registers Spectacle's default shortcuts (ADR-0005). Configuration,
    /// disabling and the alternative preset arrive with the settings window.
    /// Returns the actions whose shortcut could not be registered, with the reason.
    private func registerDefaultShortcuts() -> [LayoutAction: String] {
        var failures: [LayoutAction: String] = [:]
        for action in LayoutAction.allCases {
            guard let combo = DefaultShortcuts.spectacle[action] else { continue }
            do {
                try hotKeys.register(keyCode: UInt32(combo.keyCode), modifiers: Self.carbonModifiers(combo.modifiers)) { [weak self] in
                    self?.runner.perform(action)
                }
            } catch {
                failures[action] = error.description
                Log.shortcuts.error("""
                    Registering \(combo.displayString, privacy: .public) for \(action.rawValue, privacy: .public) \
                    failed: \(error.description, privacy: .public)
                    """)
            }
        }
        return failures
    }

    static func carbonModifiers(_ modifiers: ShortcutModifiers) -> UInt32 {
        var mask = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.control) { mask |= controlKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        return UInt32(mask)
    }
}
