import Foundation
import Testing
@testable import ZuntrioCore

@Suite struct PauseSettingsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let terminal = PauseSettings.DisabledApp(bundleID: "com.apple.Terminal", name: "Terminal")
    let figma = PauseSettings.DisabledApp(bundleID: "com.figma.Desktop", name: "Figma")

    @Test func activeByDefault() {
        #expect(PauseSettings().shortcutsActive(at: now, frontmostBundleID: "com.apple.Safari"))
    }

    @Test func pauseForHoursThenExpire() {
        var s = PauseSettings()
        s.pause(hours: 1, from: now)
        #expect(!s.shortcutsActive(at: now, frontmostBundleID: nil))
        #expect(!s.shortcutsActive(at: now.addingTimeInterval(3599), frontmostBundleID: nil))
        #expect(s.shortcutsActive(at: now.addingTimeInterval(3600), frontmostBundleID: nil))
        let cleared = s.clearExpired(at: now.addingTimeInterval(3600))
        #expect(cleared)
        #expect(s.pausedUntil == nil)
        let clearedAgain = s.clearExpired(at: now.addingTimeInterval(7200))
        #expect(!clearedAgain)
    }

    @Test func customHoursAreClamped() {
        var s = PauseSettings()
        s.pause(hours: 0, from: now)
        #expect(s.pausedUntil == now.addingTimeInterval(3600))
        s.pause(hours: 99, from: now)
        #expect(s.pausedUntil == now.addingTimeInterval(24 * 3600))
        s.pause(hours: 5, from: now)
        #expect(s.pausedUntil == now.addingTimeInterval(5 * 3600))
    }

    @Test func resumeClearsPause() {
        var s = PauseSettings()
        s.pause(hours: 3, from: now)
        s.resume()
        #expect(s.shortcutsActive(at: now, frontmostBundleID: nil))
    }

    @Test func disabledAppOnlyAffectsThatApp() {
        var s = PauseSettings()
        s.disable(terminal)
        #expect(!s.shortcutsActive(at: now, frontmostBundleID: "com.apple.Terminal"))
        #expect(s.shortcutsActive(at: now, frontmostBundleID: "com.apple.Safari"))
        #expect(s.shortcutsActive(at: now, frontmostBundleID: nil))
        s.enable(bundleID: "com.apple.Terminal")
        #expect(s.shortcutsActive(at: now, frontmostBundleID: "com.apple.Terminal"))
    }

    @Test func appListIsSortedUniqueAndRenameable() {
        var s = PauseSettings()
        s.disable(terminal)
        s.disable(figma)
        s.disable(PauseSettings.DisabledApp(bundleID: "com.apple.Terminal", name: "Terminal (renamed)"))
        s.disable(PauseSettings.DisabledApp(bundleID: "", name: "Nameless"))
        #expect(s.disabledApps.map(\.name) == ["Figma", "Terminal (renamed)"])
    }

    @Test func roundTrip() throws {
        var s = PauseSettings()
        s.pause(hours: 2, from: now)
        s.disable(terminal)
        #expect(PauseSettings.decode(try s.encoded()) == .loaded(s))
    }

    @Test func storedFormat() throws {
        var s = PauseSettings()
        s.disable(terminal)
        let json = String(decoding: try s.encoded(), as: UTF8.self)
        #expect(json == #"{"disabledApps":[{"bundleID":"com.apple.Terminal","name":"Terminal"}],"schemaVersion":1}"#)
    }

    @Test func newerAndCorruptData() {
        #expect(PauseSettings.decode(Data(#"{"schemaVersion":9,"disabledApps":[]}"#.utf8)) == .newerVersion(9))
        #expect(PauseSettings.decode(Data("nope".utf8)) == .corrupt)
    }
}
