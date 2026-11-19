import AppKit
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private let monitor = AccessibilityMonitor()
    private var shortcuts: ShortcutController?
    private var statusMenu: StatusMenuController?
    private var onboarding: OnboardingWindowController?
    private var settings: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortcuts = ShortcutController(hotKeys: hotKeys) { [weak self] action in
            self?.runner.perform(action)
        }
        shortcuts.apply()
        self.shortcuts = shortcuts

        let onboarding = OnboardingWindowController(monitor: monitor, shortcuts: shortcuts)
        self.onboarding = onboarding
        let settings = SettingsWindowController(model: SettingsModel(shortcuts: shortcuts, monitor: monitor))
        self.settings = settings
        let statusMenu = StatusMenuController(
            runner: runner, shortcuts: shortcuts, monitor: monitor,
            showWelcome: { onboarding.show() }, showSettings: { settings.show() }
        )
        self.statusMenu = statusMenu

        monitor.onChange = { [weak self] trusted in
            self?.onboarding?.trustChanged(trusted)
            self?.statusMenu?.trustChanged(trusted)
            self?.settings?.model.reload()
            if trusted { self?.monitor.setPolling(false) }
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
        ProofOfConceptRun.writeShortcutReportIfRequested(arguments: CommandLine.arguments, shortcuts: shortcuts)
        ProofOfConceptRun.renderOnboardingIfRequested(arguments: CommandLine.arguments, shortcuts: shortcuts)
        ProofOfConceptRun.renderSettingsIfRequested(arguments: CommandLine.arguments, settings: settings)
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }
}
