#if DEBUG
import AppKit
import SwiftUI
import ZuntrioCore

/// Debug-only scripted run used to collect evidence for the proof of concept.
///
/// Act on the frontmost app's focused window:
///
///     open -n -g Zuntrio.app --args --poc-run leftHalf,maximize,center --poc-output /path/result.json
///
/// Act on a specific process's first standard window (used with the fixture
/// host below, because a background app can't take focus on macOS 14+):
///
///     open -n -g Zuntrio.app --args --poc-fixture-host          # shows the test window, stays running
///     open -n -g Zuntrio.app --args --poc-run … --poc-output … --poc-target-pid <host pid>
///
/// Add `--poc-restore` to put the window back at its original frame afterwards.
///
/// Writes geometry-only results as JSON, then quits. Launch with `open` so
/// macOS attributes the Accessibility permission to Zuntrio, not the terminal.
@MainActor
enum ProofOfConceptRun {
    private static var fixture: FixtureWindowController?

    /// `--poc-shortcut-report <path>` writes registration results and macOS
    /// shortcut conflicts for every preset, then quits.
    static func writeShortcutReportIfRequested(arguments: [String], shortcuts: ShortcutController) {
        guard let output = value(after: "--poc-shortcut-report", in: arguments) else { return }
        // Optional settings changes through the real controller (and so the
        // real persistence path): "preset:alternative", "disable:center",
        // "enable:center", "restore".
        for op in (value(after: "--poc-shortcut-ops", in: arguments) ?? "").split(separator: ",") {
            let parts = op.split(separator: ":").map(String.init)
            switch (parts.first, parts.count > 1 ? parts[1] : nil) {
            case ("preset", let name?): ShortcutPreset(rawValue: name).map(shortcuts.select)
            case ("disable", let name?): LayoutAction(rawValue: name).map { shortcuts.setEnabled(false, for: $0) }
            case ("enable", let name?): LayoutAction(rawValue: name).map { shortcuts.setEnabled(true, for: $0) }
            case ("restore", _): shortcuts.restoreDefaults()
            default: break
            }
        }
        let system = SystemShortcuts.enabledCombos()
        var presets: [String: Any] = [:]
        for preset in ShortcutPreset.allCases {
            let conflicts = ShortcutSettings(preset: preset).systemConflicts(reserved: system)
            presets[preset.rawValue] = conflicts.map { "\($0.rawValue) \(preset.bindings[$0]?.displayString ?? "")" }
        }
        write([
            "activePreset": shortcuts.settings.preset.rawValue,
            "disabled": LayoutAction.allCases.filter { !shortcuts.settings.isEnabled($0) }.map(\.rawValue),
            "registered": shortcuts.settings.effectiveBindings.count - shortcuts.failures.count,
            "failures": shortcuts.failures.map { "\($0.key.rawValue): \($0.value)" },
            "systemConflictsActive": shortcuts.systemConflicts.map(\.rawValue).sorted(),
            "systemConflictsByPreset": presets,
            "enabledMacOSShortcuts": system.count,
        ], to: output)
        NSApp.terminate(nil)
    }

    /// `--poc-render-onboarding <directory>` renders the welcome view in both
    /// permission states to PNG (for layout review), then quits.
    static func renderOnboardingIfRequested(arguments: [String], shortcuts: ShortcutController) {
        guard let directory = value(after: "--poc-render-onboarding", in: arguments) else { return }
        let examples: [LayoutAction] = [.leftHalf, .rightHalf, .maximize, .center, .nextDisplay]
        for trusted in [false, true] {
            let model = OnboardingModel(
                isTrusted: trusted,
                examples: examples.map { ($0.displayName, shortcuts.combo(for: $0)?.displayString ?? "—") }
            )
            let view = OnboardingView(model: model).background(Color(nsColor: .windowBackgroundColor))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage else { continue }
            let rep = NSBitmapImageRep(cgImage: image)
            let name = trusted ? "onboarding-granted.png" : "onboarding-needed.png"
            do {
                try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
            } catch {
                Log.actions.error("Rendering onboarding failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        NSApp.terminate(nil)
    }

    static func startIfRequested(arguments: [String], runner defaultRunner: WindowActionRunner) {
        if arguments.contains("--poc-fixture-host") {
            let controller = FixtureWindowController()
            fixture = controller
            controller.show()
            return
        }
        guard let actionsArgument = value(after: "--poc-run", in: arguments),
              let output = value(after: "--poc-output", in: arguments) else { return }
        let actions = actionsArgument.split(separator: ",").compactMap { LayoutAction(rawValue: String($0)) }
        let targetPID = value(after: "--poc-target-pid", in: arguments).flatMap { pid_t($0) }
        // Never fall back to the frontmost window when a specific target was
        // asked for but can't be parsed: that would move the user's windows.
        if arguments.contains("--poc-target-pid") && (targetPID == nil || targetPID ?? 0 <= 0) {
            write(["error": "invalid --poc-target-pid"], to: output)
            NSApp.terminate(nil)
            return
        }
        if actions.isEmpty {
            write(["error": "no valid actions in --poc-run"], to: output)
            NSApp.terminate(nil)
            return
        }
        let provider: any WindowProviding = targetPID.map { ProcessWindowProvider(pid: $0) } ?? AXWindowProvider()
        let runner = targetPID == nil ? defaultRunner : WindowActionRunner(provider: provider)
        let restore = arguments.contains("--poc-restore")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            var entries: [[String: Any]] = []
            for action in actions {
                let report = runner.perform(action)
                entries.append(encode(report))
                try? await Task.sleep(for: .milliseconds(400))
            }

            // Put the window back where it started, so tests against real
            // apps leave the user's layout untouched.
            var restored: [String: Any] = [:]
            if restore, let original = entries.first.flatMap({ $0["before"] as? [Double] }), original.count == 4 {
                let frame = CGRect(x: original[0], y: original[1], width: original[2], height: original[3])
                do throws(WindowAccessError) {
                    let actual = try provider.focusedWindow().setFrame(frame)
                    restored = ["requested": rect(frame), "actual": rect(actual)]
                } catch {
                    restored = ["error": error.description]
                }
            }

            let document: [String: Any] = [
                "trusted": AccessibilityPermission.isTrusted,
                "targetPID": targetPID.map { Int($0) } ?? -1,
                "displays": DisplayProvider.current().map { ["frame": rect($0.frame), "visibleFrame": rect($0.visibleFrame)] },
                "results": entries,
                "restore": restored,
            ]
            write(document, to: output)
            NSApp.terminate(nil)
        }
    }

    /// Targets the first standard window of a given process instead of the
    /// frontmost app. Debug only.
    private struct ProcessWindowProvider: WindowProviding {
        let pid: pid_t

        func focusedWindow() throws(WindowAccessError) -> any ManagedWindow {
            guard AccessibilityPermission.isTrusted else { throw .notTrusted }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.5)
            let value = try AX.copyAttribute(app, kAXWindowsAttribute)
            guard let windows = value as? [AXUIElement] else { throw .noFocusedWindow }
            for window in windows where AX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole {
                return AXWindow(element: window, application: app)
            }
            throw .noFocusedWindow
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func encode(_ report: ActionReport) -> [String: Any] {
        var entry: [String: Any] = ["action": report.action.rawValue, "summary": report.summary]
        switch report.result {
        case .exact: entry["result"] = "exact"
        case .clamped: entry["result"] = "clamped"
        case .ignored: entry["result"] = "ignored"
        case .alreadyInPlace: entry["result"] = "alreadyInPlace"
        case .nothingToDo: entry["result"] = "nothingToDo"
        case .failed(let error):
            entry["result"] = "failed"
            entry["reason"] = error.description
        }
        if let before = report.before { entry["before"] = rect(before) }
        if let requested = report.requested { entry["requested"] = rect(requested) }
        if let actual = report.actual { entry["actual"] = rect(actual) }
        return entry
    }

    private static func rect(_ r: CGRect) -> [Double] {
        [r.minX, r.minY, r.width, r.height].map { Double($0) }
    }

    private static func write(_ document: [String: Any], to path: String) {
        do {
            let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            Log.actions.error("Writing proof-of-concept results failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
