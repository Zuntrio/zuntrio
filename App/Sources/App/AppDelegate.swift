import AppKit
import ZuntrioCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let runner = WindowActionRunner(provider: AXWindowProvider())
    private let hotKeys = HotKeyCenter()
    private let monitor = AccessibilityMonitor()
    private let pause = PauseController(defaults: AppDelegate.defaults)
    private let updates = UpdateChecker(defaults: AppDelegate.defaults)
    private var shortcuts: ShortcutController?
    private var statusMenu: StatusMenuController?
    private var onboarding: OnboardingWindowController?
    private var settings: SettingsWindowController?

    /// The settings store: the user's own, or a throwaway one in UI-test mode.
    private nonisolated static var defaults: UserDefaults {
        #if DEBUG
        if UITesting.isActive {
            guard let defaults = UITesting.defaults else {
                // Never fall back to the user's real settings in a test run.
                exit(3)
            }
            return defaults
        }
        #endif
        return .standard
    }

    /// False in UI-test mode, so tests never take over the user's global shortcuts.
    private var hotKeysAllowed: Bool {
        #if DEBUG
        return !UITesting.isActive
        #else
        return true
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shortcuts = ShortcutController(hotKeys: hotKeys, defaults: Self.defaults) { [weak self] action in
            self?.runner.perform(action)
        }
        if hotKeysAllowed {
            shortcuts.apply()
            shortcuts.setSuspended(!pause.shortcutsActive)
        } else {
            shortcuts.setSuspended(true)
        }
        self.shortcuts = shortcuts

        let onboarding = OnboardingWindowController(monitor: monitor, shortcuts: shortcuts, defaults: Self.defaults)
        self.onboarding = onboarding
        let settings = SettingsWindowController(model: SettingsModel(shortcuts: shortcuts, pause: pause, monitor: monitor, updates: updates))
        self.settings = settings
        let statusMenu = StatusMenuController(
            runner: runner, shortcuts: shortcuts, pause: pause, monitor: monitor, updates: updates,
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
            self.shortcuts?.setSuspended(!self.hotKeysAllowed || !self.pause.shortcutsActive)
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

        // Sends nothing unless the user turned on automatic checks (ADR-0007).
        if hotKeysAllowed { updates.start() }

        if !monitor.isTrusted {
            Log.permissions.info("Accessibility not granted at launch")
        }
        #if DEBUG
        let scripted = CommandLine.arguments.contains { $0.hasPrefix("--poc-") } || UITesting.isActive
        switch UITesting.windowToShow {
        case "settings": settings.show()
        case "welcome": onboarding.show()
        default: break
        }
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
        ProofOfConceptRun.writeUpdateCheckIfRequested(arguments: CommandLine.arguments, updates: updates)
        ProofOfConceptRun.writeDiagnosticsIfRequested(
            arguments: CommandLine.arguments, shortcuts: shortcuts, pause: pause,
            monitor: monitor, updates: updates, runner: runner
        )
        ProofOfConceptRun.startIfRequested(arguments: CommandLine.arguments, runner: runner)
        #endif
    }
}
