import AppKit
import ZuntrioCore

/// Gathers the facts for "Copy Diagnostics…". Only Zuntrio state, macOS version,
/// Mac model and display geometry; see `DiagnosticsReport` for what's excluded.
@MainActor
enum Diagnostics {
    static func report(
        shortcuts: ShortcutController, pause: PauseController, monitor: AccessibilityMonitor,
        updates: UpdateChecker, runner: WindowActionRunner
    ) -> DiagnosticsReport {
        let settings = shortcuts.settings
        let actions = WindowAction.allCases
        let unavailable = actions.compactMap { action -> DiagnosticsReport.UnavailableShortcut? in
            if shortcuts.failures[action] != nil { return .init(action: action, reason: "in use by another app") }
            if shortcuts.systemConflicts.contains(action) { return .init(action: action, reason: "also a macOS shortcut") }
            return nil
        }
        let login = switch LaunchAtLogin.state {
        case .enabled: "on"
        case .disabled: "off"
        case .requiresApproval: "waiting for approval in System Settings"
        }
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let lastResult = runner.lastReport.flatMap { $0.result == .exact ? nil : $0.summary }

        return DiagnosticsReport(
            appVersion: ReleaseInfo.displayVersion,
            build: build,
            installedWithHomebrew: UpdateChecker.installedWithHomebrew,
            inApplicationsFolder: Bundle.main.bundlePath.hasPrefix("/Applications/"),
            macOSVersion: macOSVersion,
            macModel: sysctlString("hw.model") ?? "unknown",
            architecture: architecture,
            runningUnderRosetta: sysctlInt("sysctl.proc_translated") == 1,
            accessibilityGranted: monitor.isTrusted,
            preset: settings.preset,
            enabledShortcuts: actions.filter { settings.isEnabled($0) }.count,
            totalShortcuts: actions.count,
            unavailableShortcuts: unavailable,
            shortcutsTurnedOff: pause.isPausedNow,
            appsWithShortcutsOff: pause.settings.disabledApps.count,
            launchAtLogin: login,
            automaticUpdateChecks: updates.checksAutomatically,
            displays: displays,
            lastResult: lastResult
        )
    }

    private static var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let number = v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"
        return sysctlString("kern.osversion").map { "\(number) (\($0))" } ?? number
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    /// Display geometry in Accessibility coordinates (top-left origin), like the logs.
    private static var displays: [DiagnosticsReport.Display] {
        let screens = NSScreen.screens
        let geometry = DisplayProvider.current()
        return zip(screens, geometry).map { screen, display in
            DiagnosticsReport.Display(
                frame: display.frame,
                visibleFrame: display.visibleFrame,
                scale: Double(screen.backingScaleFactor),
                isPrimary: screen.frame.origin == .zero
            )
        }
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func sysctlInt(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

/// Shows exactly what will be copied, and copies only on "Copy".
@MainActor
enum DiagnosticsPrompt {
    static func show(_ report: DiagnosticsReport) {
        let text = report.text
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Copy diagnostics for a bug report?"
        alert.informativeText = "This is everything that will be copied. It contains no window titles, app names, file paths or personal data. Paste it into your GitHub issue."

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let textView = NSTextView(frame: scroll.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.autoresizingMask = [.width]
        scroll.documentView = textView
        alert.accessoryView = scroll

        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
