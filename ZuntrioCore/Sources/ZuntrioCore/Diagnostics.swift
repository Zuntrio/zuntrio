import CoreGraphics
import Foundation

/// The text behind "Copy Diagnostics…", for bug reports. It holds only facts about
/// Zuntrio, macOS, the Mac model and display geometry: never window titles, app
/// names, file paths, serial numbers or anything typed. The user sees the full text
/// before anything is copied.
public struct DiagnosticsReport: Sendable, Equatable {
    public struct Display: Sendable, Equatable {
        public var frame: CGRect
        public var visibleFrame: CGRect
        public var scale: Double
        public var isPrimary: Bool

        public init(frame: CGRect, visibleFrame: CGRect, scale: Double, isPrimary: Bool) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.scale = scale
            self.isPrimary = isPrimary
        }
    }

    public struct UnavailableShortcut: Sendable, Equatable {
        public var action: WindowAction
        /// A fixed phrase such as "in use by another app", never app-provided text.
        public var reason: String

        public init(action: WindowAction, reason: String) {
            self.action = action
            self.reason = reason
        }
    }

    public var appVersion: String
    public var build: String
    public var installedWithHomebrew: Bool
    public var inApplicationsFolder: Bool
    public var macOSVersion: String
    public var macModel: String
    public var architecture: String
    public var runningUnderRosetta: Bool
    public var accessibilityGranted: Bool
    public var preset: ShortcutPreset
    public var enabledShortcuts: Int
    public var totalShortcuts: Int
    public var unavailableShortcuts: [UnavailableShortcut]
    public var shortcutsTurnedOff: Bool
    public var appsWithShortcutsOff: Int
    public var launchAtLogin: String
    public var automaticUpdateChecks: Bool
    public var displays: [Display]
    /// `ActionReport.summary` of the last action that wasn't exact, if any.
    public var lastResult: String?

    public init(
        appVersion: String, build: String, installedWithHomebrew: Bool, inApplicationsFolder: Bool,
        macOSVersion: String, macModel: String, architecture: String, runningUnderRosetta: Bool,
        accessibilityGranted: Bool, preset: ShortcutPreset, enabledShortcuts: Int, totalShortcuts: Int,
        unavailableShortcuts: [UnavailableShortcut], shortcutsTurnedOff: Bool, appsWithShortcutsOff: Int,
        launchAtLogin: String, automaticUpdateChecks: Bool, displays: [Display], lastResult: String?
    ) {
        self.appVersion = appVersion
        self.build = build
        self.installedWithHomebrew = installedWithHomebrew
        self.inApplicationsFolder = inApplicationsFolder
        self.macOSVersion = macOSVersion
        self.macModel = macModel
        self.architecture = architecture
        self.runningUnderRosetta = runningUnderRosetta
        self.accessibilityGranted = accessibilityGranted
        self.preset = preset
        self.enabledShortcuts = enabledShortcuts
        self.totalShortcuts = totalShortcuts
        self.unavailableShortcuts = unavailableShortcuts
        self.shortcutsTurnedOff = shortcutsTurnedOff
        self.appsWithShortcutsOff = appsWithShortcutsOff
        self.launchAtLogin = launchAtLogin
        self.automaticUpdateChecks = automaticUpdateChecks
        self.displays = displays
        self.lastResult = lastResult
    }

    /// Plain text that reads well pasted into a GitHub issue.
    public var text: String {
        var lines: [String] = []
        let install = installedWithHomebrew ? "Homebrew" : "download"
        lines.append("Zuntrio: \(appVersion) (build \(build)), installed via \(install)\(inApplicationsFolder ? "" : ", not in /Applications")")
        lines.append("macOS: \(macOSVersion)")
        lines.append("Mac: \(macModel), \(architecture)\(runningUnderRosetta ? " (running under Rosetta)" : "")")
        lines.append("Accessibility: \(accessibilityGranted ? "granted" : "not granted")")

        var shortcuts = "Shortcuts: \(preset.rawValue) preset, \(enabledShortcuts) of \(totalShortcuts) on"
        if shortcutsTurnedOff { shortcuts += ", turned off for now" }
        if appsWithShortcutsOff > 0 {
            shortcuts += ", off in \(appsWithShortcutsOff) app\(appsWithShortcutsOff == 1 ? "" : "s")"
        }
        lines.append(shortcuts)
        for item in unavailableShortcuts {
            lines.append("  unavailable: \(item.action.rawValue) (\(item.reason))")
        }

        lines.append("Launch at login: \(launchAtLogin)")
        lines.append("Automatic update checks: \(automaticUpdateChecks ? "on" : "off")")

        lines.append("Displays: \(displays.count)")
        for (index, display) in displays.enumerated() {
            let scale = display.scale == display.scale.rounded() ? "\(Int(display.scale))" : String(format: "%.2f", display.scale)
            var line = "  \(index + 1): \(Self.size(display.frame)) pt @\(scale)x at \(Self.origin(display.frame))"
            line += ", usable \(Self.origin(display.visibleFrame)) \(Self.size(display.visibleFrame))"
            if display.isPrimary { line += " (primary)" }
            lines.append(line)
        }

        lines.append("Last result: \(lastResult ?? "none")")
        return lines.joined(separator: "\n")
    }

    private static func size(_ rect: CGRect) -> String {
        "\(Int(rect.width.rounded()))×\(Int(rect.height.rounded()))"
    }

    private static func origin(_ rect: CGRect) -> String {
        "\(Int(rect.minX.rounded())),\(Int(rect.minY.rounded()))"
    }
}
