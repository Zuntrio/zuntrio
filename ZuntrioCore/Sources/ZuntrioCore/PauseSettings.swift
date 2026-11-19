import Foundation

/// When Zuntrio's shortcuts are switched off: for a while (everywhere), or
/// always while a particular app is in front. While off, the key presses go to
/// the app instead (the hotkeys are released). Stored locally as versioned JSON;
/// never logged.
public struct PauseSettings: Sendable, Equatable {
    public struct DisabledApp: Sendable, Equatable, Hashable, Codable {
        public let bundleID: String
        /// Display name, for the menu and Settings.
        public var name: String

        public init(bundleID: String, name: String) {
            self.bundleID = bundleID
            self.name = name
        }
    }

    /// Allowed range for "disable for N hours".
    public static let hourRange: ClosedRange<Int> = 1...24

    public var pausedUntil: Date?
    public private(set) var disabledApps: [DisabledApp]

    public init(pausedUntil: Date? = nil, disabledApps: [DisabledApp] = []) {
        self.pausedUntil = pausedUntil
        self.disabledApps = disabledApps.sorted(by: Self.byName)
    }

    // MARK: State

    public func isPaused(at now: Date) -> Bool {
        pausedUntil.map { now < $0 } ?? false
    }

    public func isDisabled(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return disabledApps.contains { $0.bundleID == bundleID }
    }

    /// Whether the global shortcuts should be registered right now.
    public func shortcutsActive(at now: Date, frontmostBundleID: String?) -> Bool {
        !isPaused(at: now) && !isDisabled(bundleID: frontmostBundleID)
    }

    // MARK: Changes

    /// Switches shortcuts off for `hours` (clamped to `hourRange`) from `now`.
    public mutating func pause(hours: Int, from now: Date) {
        let clamped = min(max(hours, Self.hourRange.lowerBound), Self.hourRange.upperBound)
        pausedUntil = now.addingTimeInterval(TimeInterval(clamped) * 3600)
    }

    public mutating func resume() {
        pausedUntil = nil
    }

    /// Drops a pause that has run out. Returns true if something changed.
    @discardableResult
    public mutating func clearExpired(at now: Date) -> Bool {
        guard let until = pausedUntil, now >= until else { return false }
        pausedUntil = nil
        return true
    }

    public mutating func disable(_ app: DisabledApp) {
        guard !app.bundleID.isEmpty else { return }
        if let index = disabledApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            disabledApps[index].name = app.name
        } else {
            disabledApps.append(app)
            disabledApps.sort(by: Self.byName)
        }
    }

    public mutating func enable(bundleID: String) {
        disabledApps.removeAll { $0.bundleID == bundleID }
    }

    private static func byName(_ a: DisabledApp, _ b: DisabledApp) -> Bool {
        a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }

    // MARK: Persistence

    public static let schemaVersion = 1

    private struct Stored: Codable {
        var schemaVersion: Int
        var pausedUntil: Date?
        var disabledApps: [DisabledApp]
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Stored(schemaVersion: Self.schemaVersion, pausedUntil: pausedUntil, disabledApps: disabledApps))
    }

    public enum DecodeOutcome: Sendable, Equatable {
        case loaded(PauseSettings)
        case newerVersion(Int)
        case corrupt
    }

    public static func decode(_ data: Data) -> DecodeOutcome {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode(Stored.self, from: data) else { return .corrupt }
        guard stored.schemaVersion <= schemaVersion else { return .newerVersion(stored.schemaVersion) }
        var settings = PauseSettings(pausedUntil: stored.pausedUntil)
        for app in stored.disabledApps { settings.disable(app) }
        return .loaded(settings)
    }
}
