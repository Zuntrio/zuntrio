import Foundation

/// The user's shortcut configuration: a preset plus per-action changes.
/// Persisted as versioned JSON (see `encoded()` / `decode(_:)`).
public struct ShortcutSettings: Sendable, Equatable {
    public enum Binding: Sendable, Equatable {
        case disabled
        case combo(KeyCombo)
    }

    public var preset: ShortcutPreset
    /// Actions whose shortcut differs from the preset. Missing = use the preset.
    public var overrides: [LayoutAction: Binding]

    public init(preset: ShortcutPreset = .spectacle, overrides: [LayoutAction: Binding] = [:]) {
        self.preset = preset
        self.overrides = overrides
    }

    public static let `default` = ShortcutSettings()

    /// The shortcut each action currently has (disabled actions are absent).
    public var effectiveBindings: [LayoutAction: KeyCombo] {
        var result = preset.bindings
        for (action, binding) in overrides {
            switch binding {
            case .disabled: result[action] = nil
            case .combo(let combo): result[action] = combo
            }
        }
        return result
    }

    public func combo(for action: LayoutAction) -> KeyCombo? {
        effectiveBindings[action]
    }

    public func isEnabled(_ action: LayoutAction) -> Bool {
        combo(for: action) != nil
    }

    /// Switching preset keeps explicit disables but drops custom combos, which
    /// could collide with the new preset's defaults.
    public mutating func select(_ newPreset: ShortcutPreset) {
        preset = newPreset
        overrides = overrides.filter { $0.value == .disabled }
    }

    public mutating func setEnabled(_ enabled: Bool, for action: LayoutAction) {
        if enabled {
            if overrides[action] == .disabled { overrides[action] = nil }
            // Re-enabling must not create a duplicate if another action has
            // since taken this action's preset combo.
            if let combo = combo(for: action), conflict(for: combo, assigningTo: action) != nil {
                overrides[action] = .disabled
            }
        } else {
            overrides[action] = .disabled
        }
    }

    /// Assigns a custom shortcut. Fails without changing anything if the
    /// combination is invalid or already used by another action.
    public mutating func assign(_ combo: KeyCombo, to action: LayoutAction) -> ShortcutIssue? {
        if let issue = combo.validationIssue { return issue }
        if let other = conflict(for: combo, assigningTo: action) { return .usedByAction(other) }
        overrides[action] = combo == preset.bindings[action] ? nil : .combo(combo)
        return nil
    }

    /// Restores the preset's defaults for every action.
    public mutating func restoreDefaults() {
        overrides = [:]
    }

    /// The other action already using `combo`, if any.
    public func conflict(for combo: KeyCombo, assigningTo action: LayoutAction) -> LayoutAction? {
        effectiveBindings.first { $0.key != action && $0.value == combo }?.key
    }

    /// Actions whose current shortcut matches an enabled macOS shortcut.
    public func systemConflicts(reserved: Set<KeyCombo>) -> [LayoutAction] {
        effectiveBindings.filter { reserved.contains($0.value) }.map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Disables custom shortcuts that are invalid or used by more than one
    /// action (possible only with hand-edited or foreign data). Disabling never
    /// creates a new conflict, so one pass is enough.
    mutating func disableInvalidOverrides() {
        for (action, binding) in overrides {
            if case .combo(let combo) = binding, combo.validationIssue != nil {
                overrides[action] = .disabled
            }
        }
        var owners: [KeyCombo: [LayoutAction]] = [:]
        for (action, combo) in effectiveBindings { owners[combo, default: []].append(action) }
        for actions in owners.values where actions.count > 1 {
            for action in actions {
                if case .combo = overrides[action] { overrides[action] = .disabled }
            }
        }
    }

    // MARK: - Persistence

    /// Bump when the stored format changes, and add a migration in `decode`.
    public static let schemaVersion = 1

    private struct Stored: Codable {
        var schemaVersion: Int
        var preset: String
        /// Keyed by `LayoutAction.rawValue`; a nil combo means disabled.
        var overrides: [String: StoredBinding]
    }

    private struct StoredBinding: Codable {
        var combo: KeyCombo?
    }

    public func encoded() throws -> Data {
        let stored = Stored(
            schemaVersion: Self.schemaVersion,
            preset: preset.rawValue,
            overrides: Dictionary(uniqueKeysWithValues: overrides.map { action, binding in
                switch binding {
                case .disabled: (action.rawValue, StoredBinding(combo: nil))
                case .combo(let combo): (action.rawValue, StoredBinding(combo: combo))
                }
            })
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(stored)
    }

    public enum DecodeOutcome: Sendable, Equatable {
        case loaded(ShortcutSettings)
        /// Stored by a newer Zuntrio. Use defaults for now but don't overwrite the data.
        case newerVersion(Int)
        /// Unreadable data. Use defaults.
        case corrupt
    }

    /// Reads stored settings. Unknown actions or presets (from other versions)
    /// are skipped; invalid or duplicate combos are dropped rather than registered.
    public static func decode(_ data: Data) -> DecodeOutcome {
        guard let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return .corrupt }
        guard stored.schemaVersion <= schemaVersion else { return .newerVersion(stored.schemaVersion) }
        // schemaVersion 1 is the first format; future migrations go here.

        var settings = ShortcutSettings(preset: ShortcutPreset(rawValue: stored.preset) ?? .spectacle)
        for (key, binding) in stored.overrides {
            guard let action = LayoutAction(rawValue: key) else { continue }
            settings.overrides[action] = binding.combo.map { .combo($0) } ?? .disabled
        }
        settings.disableInvalidOverrides()
        return .loaded(settings)
    }
}
