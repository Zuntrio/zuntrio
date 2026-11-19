import AppKit
import SwiftUI
import ZuntrioCore

/// Hosts the SwiftUI welcome view in a plain AppKit window.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    /// Bump to show the welcome window again after a significant change.
    static let currentVersion = 1
    private static let completedKey = "onboardingCompletedVersion"

    private let monitor: AccessibilityMonitor
    private let defaults: UserDefaults
    private let model: OnboardingModel
    private var window: NSWindow?

    init(monitor: AccessibilityMonitor, shortcuts: ShortcutController, defaults: UserDefaults = .standard) {
        self.monitor = monitor
        self.defaults = defaults
        let examples: [LayoutAction] = [.leftHalf, .rightHalf, .maximize, .center, .nextDisplay]
        model = OnboardingModel(
            isTrusted: monitor.isTrusted,
            examples: examples.map { ($0.displayName, shortcuts.combo(for: $0)?.displayString ?? "—") }
        )
        super.init()
        model.openSettings = {
            if !AccessibilityPermission.requestTrustPrompt() {
                AccessibilityPermission.openSystemSettings()
            }
        }
        model.finish = { [weak self] in self?.close() }
    }

    var isVisible: Bool { window?.isVisible == true }

    /// First launch, or permission missing.
    var shouldShowAtLaunch: Bool {
        defaults.integer(forKey: Self.completedKey) < Self.currentVersion || !monitor.isTrusted
    }

    func trustChanged(_ trusted: Bool) {
        model.isTrusted = trusted
    }

    func show() {
        model.isTrusted = monitor.isTrusted
        let window = self.window ?? makeWindow()
        self.window = window
        monitor.setPolling(!model.isTrusted)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        monitor.setPolling(false)
        if model.isTrusted {
            defaults.set(Self.currentVersion, forKey: Self.completedKey)
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(model: model)))
        window.title = "Welcome to Zuntrio"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
