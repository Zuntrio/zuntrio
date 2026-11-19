#if DEBUG
import AppKit
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
/// Writes geometry-only results as JSON, then quits. Launch with `open` so
/// macOS attributes the Accessibility permission to Zuntrio, not the terminal.
@MainActor
enum ProofOfConceptRun {
    private static var fixture: FixtureWindowController?

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
        let runner = targetPID.map { WindowActionRunner(provider: ProcessWindowProvider(pid: $0)) } ?? defaultRunner

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            var entries: [[String: Any]] = []
            for action in actions {
                let report = runner.perform(action)
                entries.append(encode(report))
                try? await Task.sleep(for: .milliseconds(400))
            }

            let document: [String: Any] = [
                "trusted": AccessibilityPermission.isTrusted,
                "targetPID": targetPID.map { Int($0) } ?? -1,
                "displays": DisplayProvider.current().map { ["frame": rect($0.frame), "visibleFrame": rect($0.visibleFrame)] },
                "results": entries,
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
        case .failed(let reason):
            entry["result"] = "failed"
            entry["reason"] = reason
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
