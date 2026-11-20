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
    /// Extra test windows for `--poc-fixture-kind`; kept alive while the host runs.
    private static var extraWindows: [NSWindow] = []

    /// `--poc-shortcut-report <path>` writes registration results and macOS
    /// shortcut conflicts for every preset, then quits.
    static func writeShortcutReportIfRequested(arguments: [String], shortcuts: ShortcutController, pause: PauseController) {
        guard let output = value(after: "--poc-shortcut-report", in: arguments) else { return }
        // Optional settings changes through the real controller (and so the
        // real persistence path): "preset:alternative", "disable:center",
        // "enable:center", "restore".
        for op in (value(after: "--poc-shortcut-ops", in: arguments) ?? "").split(separator: ",") {
            let parts = op.split(separator: ":").map(String.init)
            switch (parts.first, parts.count > 1 ? parts[1] : nil) {
            case ("preset", let name?): ShortcutPreset(rawValue: name).map(shortcuts.select)
            case ("disable", let name?): WindowAction(rawValue: name).map { shortcuts.setEnabled(false, for: $0) }
            case ("enable", let name?): WindowAction(rawValue: name).map { shortcuts.setEnabled(true, for: $0) }
            case ("restore", _): shortcuts.restoreDefaults()
            case ("pause", let hours?): Int(hours).map(pause.pause)
            case ("resume", _): pause.resume()
            case ("disable-app", let bundleID?): pause.disable(PauseSettings.DisabledApp(bundleID: bundleID, name: bundleID))
            case ("enable-app", let bundleID?): pause.enable(bundleID: bundleID)
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
            "suspended": shortcuts.isSuspended,
            "shortcutsActive": pause.shortcutsActive,
            "pausedUntil": pause.settings.pausedUntil.map { "\($0)" } ?? "none",
            "disabledApps": pause.settings.disabledApps.map(\.bundleID),
            "registeredHotKeys": shortcuts.registeredCount,
            "disabled": WindowAction.allCases.filter { !shortcuts.settings.isEnabled($0) }.map(\.rawValue),
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
        let examples: [WindowAction] = [.leftHalf, .rightHalf, .maximize, .center, .nextDisplay]
        for trusted in [false, true] {
            let model = OnboardingModel(
                isTrusted: trusted,
                examples: examples.map {
                    ($0.displayName, shortcuts.combo(for: $0)?.displayString ?? "—", shortcuts.combo(for: $0)?.spokenDescription ?? "no shortcut")
                }
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

    /// `--poc-render-settings <directory>` captures the real settings window
    /// (AppKit controls included) off screen, idle and while recording, then quits.
    static func renderSettingsIfRequested(arguments: [String], settings: SettingsWindowController) {
        guard let directory = value(after: "--poc-render-settings", in: arguments) else { return }
        let window = settings.makeWindow()
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFront(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            capture(window, to: directory, name: "settings.png")
            settings.model.toggleRecording(.leftHalf)
            try? await Task.sleep(for: .milliseconds(300))
            capture(window, to: directory, name: "settings-recording.png")
            settings.model.stopRecording()
            NSApp.terminate(nil)
        }
    }

    /// `--poc-diagnostics <file>`: writes the "Copy Diagnostics…" text without showing the dialog.
    static func writeDiagnosticsIfRequested(
        arguments: [String], shortcuts: ShortcutController, pause: PauseController,
        monitor: AccessibilityMonitor, updates: UpdateChecker, runner: WindowActionRunner
    ) {
        guard let output = value(after: "--poc-diagnostics", in: arguments) else { return }
        let text = Diagnostics.report(shortcuts: shortcuts, pause: pause, monitor: monitor, updates: updates, runner: runner).text
        do {
            try text.write(toFile: output, atomically: true, encoding: .utf8)
        } catch {
            Log.actions.error("Writing diagnostics failed: \(error.localizedDescription, privacy: .public)")
        }
        NSApp.terminate(nil)
    }

    /// `--poc-update-check <file>`: runs one real update check against GitHub and
    /// writes the outcome, plus what an older beta would have been offered.
    static func writeUpdateCheckIfRequested(arguments: [String], updates: UpdateChecker) {
        guard let output = value(after: "--poc-update-check", in: arguments) else { return }
        Task { @MainActor in
            var document: [String: Any] = ["current": ReleaseInfo.version]
            switch await updates.check() {
            case .available(let update): document["outcome"] = "available \(update.version) \(update.url.absoluteString)"
            case .upToDate: document["outcome"] = "upToDate"
            case .failed: document["outcome"] = "failed"
            }
            if let data = try? await GitHubReleaseFetcher().fetchReleases(),
               let releases = try? UpdatePolicy.decodeReleases(data),
               let older = ReleaseVersion("0.1.0-beta.0") {
                document["releaseTags"] = releases.map(\.tagName)
                document["offeredTo0.1.0-beta.0"] = UpdatePolicy.newestUpdate(for: older, in: releases)?.version.description ?? "nothing"
            }
            write(document, to: output)
            NSApp.terminate(nil)
        }
    }

    private static func capture(_ window: NSWindow, to directory: String, name: String) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
        } catch {
            Log.actions.error("Capturing settings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func startIfRequested(arguments: [String], runner defaultRunner: WindowActionRunner) {
        if arguments.contains("--poc-fixture-host") {
            let controller = FixtureWindowController()
            fixture = controller
            controller.show()
            // "--poc-fixture-kind panel|dialog|minimized|sheet": window types
            // Zuntrio should refuse or handle specially.
            if let kind = value(after: "--poc-fixture-kind", in: arguments) {
                showFixtureVariant(kind, main: controller)
            }
            // "--poc-fixture-hang <delay>,<duration>" (seconds): block this
            // process's main thread to simulate an app that stops responding.
            if let spec = value(after: "--poc-fixture-hang", in: arguments)?.split(separator: ",").compactMap({ Double($0) }),
               spec.count == 2 {
                // A deliberate, blocking main-thread stall (not Task.sleep, which would yield).
                DispatchQueue.main.asyncAfter(deadline: .now() + spec[0]) {
                    Thread.sleep(forTimeInterval: spec[1])
                }
            }
            return
        }
        guard let actionsArgument = value(after: "--poc-run", in: arguments),
              let output = value(after: "--poc-output", in: arguments) else { return }
        let actions = actionsArgument.split(separator: ",").compactMap { WindowAction(rawValue: String($0)) }
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
        let runner = targetPID.map {
            WindowActionRunner(provider: AXWindowProvider(fallbackToFirstStandardWindow: true), targetPID: $0)
        } ?? defaultRunner
        let restore = arguments.contains("--poc-restore")
        let burst = arguments.contains("--poc-burst")
        let pause = value(after: "--poc-pause-ms", in: arguments).flatMap(Int.init) ?? 400

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let heartbeat = MainThreadHeartbeat()
            heartbeat.start()

            var entries: [[String: Any]] = []
            if burst {
                // All presses at once, as fast as a user could mash a key.
                // Reports arrive in completion order (dropped presses first).
                var collected: [[String: Any]] = []
                runner.onReport = { collected.append(encode($0)) }
                for action in actions { runner.perform(action) }
                while runner.isBusy { try? await Task.sleep(for: .milliseconds(20)) }
                runner.onReport = nil
                entries = collected
            } else {
                for action in actions {
                    let started = Date()
                    var entry = encode(await runner.performAndWait(action))
                    entry["ms"] = Int(Date().timeIntervalSince(started) * 1000)
                    entries.append(entry)
                    try? await Task.sleep(for: .milliseconds(pause))
                }
            }
            heartbeat.stop()

            // Put the window back where it started, so tests against real
            // apps leave the user's layout untouched.
            var restored: [String: Any] = [:]
            if restore, let original = entries.lazy.compactMap({ $0["before"] as? [Double] }).first, original.count == 4 {
                let frame = CGRect(x: original[0], y: original[1], width: original[2], height: original[3])
                do throws(WindowAccessError) {
                    let actual = try await runner.setFrameDirectly(frame)
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
                "dropped": runner.droppedCount,
                "maxMainThreadGapMs": heartbeat.maxGapMs,
            ]
            write(document, to: output)
            NSApp.terminate(nil)
        }
    }

    private static func showFixtureVariant(_ kind: String, main: FixtureWindowController) {
        func panel(_ style: NSWindow.StyleMask, title: String) -> NSPanel {
            let panel = NSPanel(contentRect: NSRect(x: 300, y: 300, width: 320, height: 200),
                                styleMask: style, backing: .buffered, defer: false)
            panel.title = title
            panel.isReleasedWhenClosed = false
            return panel
        }
        switch kind {
        case "panel":
            let floating = panel([.titled, .closable, .utilityWindow], title: "Zuntrio Test Panel")
            floating.isFloatingPanel = true
            floating.makeKeyAndOrderFront(nil)
            extraWindows.append(floating)
        case "dialog":
            let dialog = panel([.titled, .closable], title: "Zuntrio Test Dialog")
            dialog.makeKeyAndOrderFront(nil)
            extraWindows.append(dialog)
        case "minimized":
            main.window.miniaturize(nil)
        case "ignore", "ignore-later":
            // A window that silently ignores frame changes (like a busy app).
            let window = IgnoringWindow(contentRect: NSRect(x: 250, y: 250, width: 640, height: 420),
                                        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Zuntrio Ignoring Window"
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            extraWindows.append(window)
            IgnoringWindow.ignoring = kind == "ignore"
            if kind == "ignore-later" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { IgnoringWindow.ignoring = true }
            }
        case "delayed":
            // A window that applies frame changes 40 ms late, like some apps do.
            let window = DelayedWindow(contentRect: NSRect(x: 250, y: 250, width: 640, height: 420),
                                       styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Zuntrio Delayed Window"
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            DelayedWindow.delaying = true
            extraWindows.append(window)
        case "sheet":
            let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
                                 styleMask: [.titled], backing: .buffered, defer: false)
            sheet.isReleasedWhenClosed = false
            extraWindows.append(sheet)
            main.window.beginSheet(sheet)
        default:
            break
        }
    }

    private final class IgnoringWindow: NSWindow {
        nonisolated(unsafe) static var ignoring = false
        override func setFrame(_ frameRect: NSRect, display flag: Bool) {
            if !Self.ignoring { super.setFrame(frameRect, display: flag) }
        }
        override func setFrameOrigin(_ point: NSPoint) {
            if !Self.ignoring { super.setFrameOrigin(point) }
        }
    }

    /// Applies frame changes at once but keeps reporting its previous frame to
    /// Accessibility for 40 ms, like apps that update asynchronously.
    private final class DelayedWindow: NSWindow {
        nonisolated(unsafe) static var delaying = false
        private var staleFrame: NSRect?
        private var staleUntil = Date.distantPast

        override func setFrame(_ frameRect: NSRect, display flag: Bool) {
            let previous = frame
            super.setFrame(frameRect, display: flag)
            markStale(previous)
        }
        override func setFrameOrigin(_ point: NSPoint) {
            let previous = frame
            super.setFrameOrigin(point)
            markStale(previous)
        }
        private func markStale(_ previous: NSRect) {
            guard Self.delaying else { return }
            if Date() >= staleUntil { staleFrame = previous }
            staleUntil = Date().addingTimeInterval(0.04)
        }
        override func accessibilityFrame() -> NSRect {
            if Date() < staleUntil, let staleFrame { return staleFrame }
            return super.accessibilityFrame()
        }
    }

    /// Measures the longest gap between main-thread timer ticks, i.e. how long
    /// the main thread was blocked.
    @MainActor
    private final class MainThreadHeartbeat {
        private var timer: Timer?
        private var last = Date()
        private(set) var maxGapMs = 0

        func start() {
            last = Date()
            let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func stop() {
            tick()
            timer?.invalidate()
        }

        private func tick() {
            let now = Date()
            maxGapMs = max(maxGapMs, Int(now.timeIntervalSince(last) * 1000))
            last = now
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
