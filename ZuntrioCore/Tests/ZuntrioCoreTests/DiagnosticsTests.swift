import CoreGraphics
import Testing
@testable import ZuntrioCore

@Suite struct DiagnosticsTests {
    func report() -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: "0.1.0 beta 2", build: "3", installedWithHomebrew: false, inApplicationsFolder: true,
            macOSVersion: "27.2.1 (26B131)", macModel: "MacBookPro17,1", architecture: "arm64", runningUnderRosetta: false,
            accessibilityGranted: true, preset: .spectacle, enabledShortcuts: 18, totalShortcuts: 18,
            unavailableShortcuts: [], shortcutsTurnedOff: false, appsWithShortcutsOff: 0,
            launchAtLogin: "off", automaticUpdateChecks: false,
            displays: [DiagnosticsReport.Display(
                frame: CGRect(x: 0, y: 0, width: 1680, height: 1050),
                visibleFrame: CGRect(x: 0, y: 31, width: 1680, height: 957),
                scale: 2, isPrimary: true)],
            lastResult: nil
        )
    }

    @Test func typicalReport() {
        #expect(report().text == """
        Zuntrio: 0.1.0 beta 2 (build 3), installed via download
        macOS: 27.2.1 (26B131)
        Mac: MacBookPro17,1, arm64
        Accessibility: granted
        Shortcuts: spectacle preset, 18 of 18 on
        Launch at login: off
        Automatic update checks: off
        Displays: 1
          1: 1680×1050 pt @2x at 0,0, usable 0,31 1680×957 (primary)
        Last result: none
        """)
    }

    @Test func detailsWhenThingsAreUnusual() {
        var r = report()
        r.installedWithHomebrew = true
        r.inApplicationsFolder = false
        r.architecture = "x86_64"
        r.runningUnderRosetta = true
        r.accessibilityGranted = false
        r.preset = .alternative
        r.enabledShortcuts = 16
        r.unavailableShortcuts = [
            .init(action: .leftHalf, reason: "in use by another app"),
            .init(action: .nextDisplay, reason: "also a macOS shortcut"),
        ]
        r.shortcutsTurnedOff = true
        r.appsWithShortcutsOff = 2
        r.automaticUpdateChecks = true
        r.displays.append(.init(frame: CGRect(x: -1440, y: -900, width: 1440, height: 900),
                                visibleFrame: CGRect(x: -1440, y: -875, width: 1440, height: 875),
                                scale: 1.5, isPrimary: false))
        r.lastResult = "Left Half: app limited the size (asked 840×957, got 836×947)"
        let text = r.text
        #expect(text.contains("installed via Homebrew, not in /Applications"))
        #expect(text.contains("Mac: MacBookPro17,1, x86_64 (running under Rosetta)"))
        #expect(text.contains("Accessibility: not granted"))
        #expect(text.contains("Shortcuts: alternative preset, 16 of 18 on, turned off for now, off in 2 apps"))
        #expect(text.contains("  unavailable: leftHalf (in use by another app)\n  unavailable: nextDisplay (also a macOS shortcut)"))
        #expect(text.contains("Automatic update checks: on"))
        #expect(text.contains("Displays: 2"))
        #expect(text.contains("  2: 1440×900 pt @1.50x at -1440,-900, usable -1440,-875 1440×875"))
        #expect(!text.contains("2: 1440×900 pt @1.50x at -1440,-900, usable -1440,-875 1440×875 (primary)"))
        #expect(text.hasSuffix("Last result: Left Half: app limited the size (asked 840×957, got 836×947)"))
    }

    @Test func singularAppCount() {
        var r = report()
        r.appsWithShortcutsOff = 1
        #expect(r.text.contains("off in 1 app\n"))
    }

    @Test func roundsFractionalGeometry() {
        var r = report()
        r.displays = [.init(frame: CGRect(x: 0.4, y: 0, width: 1511.6, height: 982.5),
                            visibleFrame: CGRect(x: 0, y: 37.2, width: 1511.6, height: 944.8),
                            scale: 2, isPrimary: true)]
        #expect(r.text.contains("1: 1512×983 pt @2x at 0,0, usable 0,37 1512×945 (primary)"))
    }
}
