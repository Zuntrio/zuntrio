import AppKit
import ZuntrioCore

/// Owns "disable shortcuts": for a number of hours, or always while a given
/// app is in front. Tells the app when the global hotkeys should be released
/// or registered again, so the keys reach the app while Zuntrio is off.
@MainActor
final class PauseController {
    private static let defaultsKey = "pause"

    private let defaults: UserDefaults
    private(set) var settings = PauseSettings()
    /// Stored by a newer Zuntrio: honoured as defaults, never overwritten.
    private var isReadOnly = false
    private(set) var shortcutsActive = true
    /// Called whenever `shortcutsActive` or the settings change.
    var onChange: (() -> Void)?

    private var expiryTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey) {
            switch PauseSettings.decode(data) {
            case .loaded(let stored): settings = stored
            case .newerVersion(let version):
                isReadOnly = true
                Log.shortcuts.error("Disable settings are from a newer version (\(version)); not saving")
            case .corrupt:
                defaults.set(data, forKey: Self.defaultsKey + ".unreadableBackup")
                Log.shortcuts.error("Stored disable settings are unreadable; starting fresh (original kept)")
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            })
        }
        shortcutsActive = settings.shortcutsActive(at: Date(), frontmostBundleID: Self.frontmostBundleID)
        scheduleExpiry()
    }

    /// The app in front, unless it is Zuntrio itself (e.g. its Settings window).
    var frontmostOtherApp: PauseSettings.DisabledApp? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              let bundleID = app.bundleIdentifier else { return nil }
        return PauseSettings.DisabledApp(bundleID: bundleID, name: app.localizedName ?? bundleID)
    }

    var isPausedNow: Bool { settings.isPaused(at: Date()) }

    func pause(hours: Int) { update { $0.pause(hours: hours, from: Date()) } }
    func resume() { update { $0.resume() } }
    func disable(_ app: PauseSettings.DisabledApp) { update { $0.disable(app) } }
    func enable(bundleID: String) { update { $0.enable(bundleID: bundleID) } }

    /// Re-checks the clock and the frontmost app.
    func evaluate() {
        if settings.clearExpired(at: Date()) { save() }
        let active = settings.shortcutsActive(at: Date(), frontmostBundleID: Self.frontmostBundleID)
        let changed = active != shortcutsActive
        shortcutsActive = active
        scheduleExpiry()
        if changed { onChange?() }
    }

    private func update(_ change: (inout PauseSettings) -> Void) {
        change(&settings)
        save()
        shortcutsActive = settings.shortcutsActive(at: Date(), frontmostBundleID: Self.frontmostBundleID)
        scheduleExpiry()
        onChange?()
    }

    private func scheduleExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let until = settings.pausedUntil, until > Date() else { return }
        let timer = Timer(fire: until, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func save() {
        guard !isReadOnly else { return }
        do {
            defaults.set(try settings.encoded(), forKey: Self.defaultsKey)
        } catch {
            Log.shortcuts.error("Saving disable settings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var frontmostBundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
