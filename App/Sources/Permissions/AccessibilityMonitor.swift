import AppKit

/// Tracks Accessibility trust while the app runs, so the UI reacts when the
/// user grants or revokes access in System Settings.
///
/// macOS posts the distributed notification "com.apple.accessibility.api"
/// when the Accessibility list changes (not formally documented, but long
/// relied on). Trust can update a moment after it fires, so the state is
/// re-read after a short delay. A 1 s poll runs only while someone is waiting
/// for the grant (the welcome window is open), as a fallback.
@MainActor
final class AccessibilityMonitor {
    private(set) var isTrusted = AccessibilityPermission.isTrusted
    var onChange: ((Bool) -> Void)?

    /// Kept for the app's lifetime (one monitor, owned by the app delegate),
    /// so the observer is never removed.
    private var observer: NSObjectProtocol?
    private var pollTimer: Timer?

    init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshSoon()
            }
        }
    }

    /// Re-reads trust now; calls `onChange` if it changed.
    func refresh() {
        let trusted = AccessibilityPermission.isTrusted
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        Log.permissions.info("Accessibility trust changed: \(trusted ? "granted" : "not granted", privacy: .public)")
        onChange?(trusted)
    }

    func setPolling(_ enabled: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard enabled else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    private func refreshSoon() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.refresh()
        }
    }
}
