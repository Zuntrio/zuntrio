import AppKit
import Carbon.HIToolbox
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortcutStatus = registerProofOfConceptShortcut()
        let menu = StatusMenuController(runner: runner, shortcutStatus: shortcutStatus)
        statusMenu = menu

        if !AccessibilityPermission.isTrusted {
            Log.permissions.info("Accessibility not granted at launch")
        }

        #if DEBUG
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }

    /// The proof of concept registers a single Spectacle default (⌥⌘← Left Half).
    /// Full shortcut management arrives in the shortcuts milestone.
    private func registerProofOfConceptShortcut() -> String {
        do {
            try hotKeys.register(
                keyCode: UInt32(kVK_LeftArrow),
                modifiers: UInt32(cmdKey | optionKey)
            ) { [weak self] in
                self?.runner.perform(.leftHalf)
            }
            return "⌥⌘← Left Half: registered"
        } catch {
            Log.shortcuts.error("Registering ⌥⌘← failed: \(String(describing: error), privacy: .public)")
            return "⌥⌘← Left Half: unavailable (\(error))"
        }
    }
}
