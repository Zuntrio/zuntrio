import AppKit
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private let monitor = AccessibilityMonitor()
    private let pause = PauseController()
    private var shortcuts: ShortcutController?
    private var statusMenu: StatusMenuController?
    private var onboarding: OnboardingWindowController?
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortcuts = ShortcutController(hotKeys: hotKeys) { [weak self] action in
            self?.runner.perform(action)
        }
        shortcuts.apply()
        shortcuts.setSuspended(!pause.shortcutsActive)
        self.shortcuts = shortcuts

        let onboarding = OnboardingWindowController(monitor: monitor, shortcuts: shortcuts)
        self.onboarding = onboarding
        let settings = SettingsWindowController(model: SettingsModel(shortcuts: shortcuts, pause: pause, monitor: monitor))
        self.settings = settings
        let statusMenu = StatusMenuController(
            runner: runner, shortcuts: shortcuts, pause: pause, monitor: monitor,
            showWelcome: { onboarding.show() }, showSettings: { settings.show() }
        )
        self.statusMenu = statusMenu

        monitor.onChange = { [weak self] trusted in
            self?.onboarding?.trustChanged(trusted)
            self?.statusMenu?.refreshIcon()
            self?.settings?.model.reload()
            if trusted { self?.monitor.setPolling(false) }
        }
        // Release the hotkeys while shortcuts are disabled (for a while, or in
        // the app in front), so the keys reach that app.
        pause.onChange = { [weak self] in
            guard let self else { return }
            self.shortcuts?.setSuspended(!self.pause.shortcutsActive)
            self.statusMenu?.refreshIcon()
            self.settings?.model.reload()
        }
        // A shortcut pressed without permission opens the explanation rather
        // than only beeping.
        runner.onReport = { [weak self] report in
            guard report.isPermissionMissing, let self else { return }
            self.monitor.refresh()
            if self.onboarding?.isVisible == false { self.onboarding?.show() }
        }

        if !monitor.isTrusted {
            Log.permissions.info("Accessibility not granted at launch")
        }
        #if DEBUG
        let scripted = CommandLine.arguments.contains { $0.hasPrefix("--poc-") }
        #else
        let scripted = false
        #endif
        if onboarding.shouldShowAtLaunch && !scripted {
            onboarding.show()
        }

        #if DEBUG
        ProofOfConceptRun.writeShortcutReportIfRequested(arguments: CommandLine.arguments, shortcuts: shortcuts, pause: pause)
        ProofOfConceptRun.renderOnboardingIfRequested(arguments: CommandLine.arguments, shortcuts: shortcuts)
        ProofOfConceptRun.renderSettingsIfRequested(arguments: CommandLine.arguments, settings: settings)
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }
}
