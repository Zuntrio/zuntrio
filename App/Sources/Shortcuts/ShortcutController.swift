import Foundation
import ZuntrioCore

/// Owns the shortcut settings: loads and saves them, registers the global
/// hotkeys, and tracks which shortcuts failed or clash with macOS shortcuts.
@MainActor
final class ShortcutController {
    private static let defaultsKey = "shortcuts"

    private let hotKeys: HotKeyCenter
    private let defaults: UserDefaults
    private let perform: (LayoutAction) -> Void

    private(set) var settings: ShortcutSettings
    /// True when the stored settings came from a newer Zuntrio: we run on
    /// defaults but never overwrite that data.
    private(set) var isReadOnly = false
    /// Actions whose hotkey could not be registered, with the reason.
    private(set) var failures: [LayoutAction: String] = [:]
    /// Actions whose shortcut matches an enabled macOS shortcut.
    private(set) var systemConflicts: Set<LayoutAction> = []

    init(hotKeys: HotKeyCenter, defaults: UserDefaults = .standard, perform: @escaping (LayoutAction) -> Void) {
        self.hotKeys = hotKeys
        self.defaults = defaults
        self.perform = perform
        settings = .default

        if let data = defaults.data(forKey: Self.defaultsKey) {
            switch ShortcutSettings.decode(data) {
            case .loaded(let stored):
                settings = stored
            case .newerVersion(let version):
                isReadOnly = true
                Log.shortcuts.error("Shortcut settings are from a newer version (\(version)); using defaults without saving")
            case .corrupt:
                Log.shortcuts.error("Stored shortcut settings are unreadable; using defaults")
            }
        }
    }

    func combo(for action: LayoutAction) -> KeyCombo? {
        settings.combo(for: action)
    }

    func select(_ preset: ShortcutPreset) {
        update { $0.select(preset) }
    }

    func setEnabled(_ enabled: Bool, for action: LayoutAction) {
        update { $0.setEnabled(enabled, for: action) }
    }

    func restoreDefaults() {
        update { $0.restoreDefaults() }
    }

    /// Unregisters everything and registers the current bindings again.
    func apply() {
        hotKeys.unregisterAll()
        failures = [:]
        for (action, combo) in settings.effectiveBindings.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            do {
                try hotKeys.register(
                    keyCode: UInt32(combo.keyCode),
                    modifiers: SystemShortcuts.carbonModifiers(combo.modifiers)
                ) { [weak self] in
                    self?.perform(action)
                }
            } catch {
                failures[action] = error.description
                Log.shortcuts.error("""
                    Registering \(combo.displayString, privacy: .public) for \(action.rawValue, privacy: .public) \
                    failed: \(error.description, privacy: .public)
                    """)
            }
        }
        systemConflicts = Set(settings.systemConflicts(reserved: SystemShortcuts.enabledCombos()))
    }

    private func update(_ change: (inout ShortcutSettings) -> Void) {
        change(&settings)
        save()
        apply()
    }

    private func save() {
        guard !isReadOnly else { return }
        do {
            defaults.set(try settings.encoded(), forKey: Self.defaultsKey)
        } catch {
            Log.shortcuts.error("Saving shortcut settings failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
