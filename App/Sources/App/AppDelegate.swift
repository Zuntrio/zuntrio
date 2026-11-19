import AppKit
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private var shortcuts: ShortcutController?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortcuts = ShortcutController(hotKeys: hotKeys) { [weak self] action in
            self?.runner.perform(action)
        }
        shortcuts.apply()
        self.shortcuts = shortcuts
        statusMenu = StatusMenuController(runner: runner, shortcuts: shortcuts)

        if !AccessibilityPermission.isTrusted {
            Log.permissions.info("Accessibility not granted at launch")
        }

        #if DEBUG
        ProofOfConceptRun.writeShortcutReportIfRequested(arguments: CommandLine.arguments, shortcuts: shortcuts)
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }
}
