import Foundation
import Testing
@testable import ZuntrioCore

@Suite struct PresetTests {
    @Test(arguments: ShortcutPreset.allCases)
    func presetCoversEveryActionUniquelyAndValidly(preset: ShortcutPreset) {
        let map = preset.bindings
        #expect(Set(map.keys) == Set(WindowAction.allCases))
        #expect(Set(map.values).count == map.count)
        #expect(map.values.allSatisfy { $0.validationIssue == nil })
    }

    @Test func alternativeLeavesCommandOptionArrowsFree() {
        let cmdOpt: ShortcutModifiers = [.command, .option]
        #expect(!DefaultShortcuts.alternative.values.contains { $0.modifiers == cmdOpt })
        #expect(DefaultShortcuts.alternative[.leftHalf]?.displayString == "⌃⌥←")
        #expect(DefaultShortcuts.alternative[.upperLeft]?.displayString == "⌃⌥U")
        #expect(DefaultShortcuts.alternative[.maximize]?.displayString == "⌃⌥↩")
    }
}

@Suite struct KeyComboTests {
    @Test func validationRequiresCommandOrControl() {
        typealias K = KeyCombo.Key
        #expect(KeyCombo(keyCode: K.c, modifiers: [.option]).validationIssue == .needsCommandOrControl)
        #expect(KeyCombo(keyCode: K.c, modifiers: [.option, .shift]).validationIssue == .needsCommandOrControl)
        #expect(KeyCombo(keyCode: K.c, modifiers: []).validationIssue == .needsCommandOrControl)
        #expect(KeyCombo(keyCode: K.c, modifiers: [.control]).validationIssue == nil)
        #expect(KeyCombo(keyCode: K.c, modifiers: [.command, .shift]).validationIssue == nil)
    }

    @Test func unknownKeysStillHaveAName() {
        #expect(KeyCombo(keyCode: 200, modifiers: [.command]).displayString == "⌘Key 200")
        #expect(KeyCombo(keyCode: 42, modifiers: [.control]).displayString == "⌃\\")
    }
}

@Suite struct ShortcutSettingsTests {
    let ctrlCmdM = KeyCombo(keyCode: 46, modifiers: [.control, .command])

    @Test func defaultsAreSpectacle() {
        #expect(ShortcutSettings.default.effectiveBindings == DefaultShortcuts.spectacle)
    }

    @Test func disableAndReenable() {
        var settings = ShortcutSettings()
        settings.setEnabled(false, for: .center)
        #expect(!settings.isEnabled(.center))
        #expect(settings.effectiveBindings.count == WindowAction.allCases.count - 1)
        settings.setEnabled(true, for: .center)
        #expect(settings.combo(for: .center) == DefaultShortcuts.spectacle[.center])
        #expect(settings.overrides.isEmpty)
    }

    @Test func assignCustomCombo() {
        var settings = ShortcutSettings()
        #expect(settings.assign(ctrlCmdM, to: .maximize) == nil)
        #expect(settings.combo(for: .maximize) == ctrlCmdM)
    }

    @Test func assignRejectsConflictsAndInvalidCombos() {
        var settings = ShortcutSettings()
        let leftHalf = DefaultShortcuts.spectacle[.leftHalf]!
        #expect(settings.assign(leftHalf, to: .center) == .usedByAction(.leftHalf))
        #expect(settings.assign(KeyCombo(keyCode: 8, modifiers: [.option]), to: .center) == .needsCommandOrControl)
        #expect(settings == ShortcutSettings())
    }

    @Test func assigningThePresetComboRemovesTheOverride() {
        var settings = ShortcutSettings()
        _ = settings.assign(ctrlCmdM, to: .center)
        _ = settings.assign(DefaultShortcuts.spectacle[.center]!, to: .center)
        #expect(settings.overrides.isEmpty)
    }

    @Test func freedComboCanBeReused() {
        var settings = ShortcutSettings()
        let centerCombo = DefaultShortcuts.spectacle[.center]!
        settings.setEnabled(false, for: .center)
        #expect(settings.assign(centerCombo, to: .maximize) == nil)
    }

    @Test func reenablingDoesNotCreateDuplicates() {
        var settings = ShortcutSettings()
        let centerCombo = DefaultShortcuts.spectacle[.center]!
        settings.setEnabled(false, for: .center)
        _ = settings.assign(centerCombo, to: .maximize)
        settings.setEnabled(true, for: .center)
        #expect(!settings.isEnabled(.center))
        #expect(settings.combo(for: .maximize) == centerCombo)
    }

    @Test func restoreDefaultsClearsEverything() {
        var settings = ShortcutSettings(preset: .alternative)
        settings.setEnabled(false, for: .center)
        _ = settings.assign(ctrlCmdM, to: .maximize)
        settings.restoreDefaults()
        #expect(settings.effectiveBindings == DefaultShortcuts.alternative)
    }

    @Test func switchingPresetKeepsDisablesDropsCustomCombos() {
        var settings = ShortcutSettings()
        settings.setEnabled(false, for: .center)
        _ = settings.assign(ctrlCmdM, to: .maximize)
        settings.select(.alternative)
        #expect(!settings.isEnabled(.center))
        #expect(settings.combo(for: .maximize) == DefaultShortcuts.alternative[.maximize])
    }

    @Test func systemConflictsAreListed() {
        let settings = ShortcutSettings()
        let reserved: Set<KeyCombo> = [DefaultShortcuts.spectacle[.nextThird]!, ctrlCmdM]
        #expect(settings.systemConflicts(reserved: reserved) == [.nextThird])
    }
}

@Suite struct ShortcutPersistenceTests {
    @Test func roundTrip() throws {
        var settings = ShortcutSettings(preset: .alternative)
        settings.setEnabled(false, for: .center)
        _ = settings.assign(KeyCombo(keyCode: 46, modifiers: [.control, .command]), to: .maximize)
        #expect(ShortcutSettings.decode(try settings.encoded()) == .loaded(settings))
    }

    @Test func storedFormatIsVersionedJSON() throws {
        var settings = ShortcutSettings()
        settings.setEnabled(false, for: .center)
        let json = String(decoding: try settings.encoded(), as: UTF8.self)
        #expect(json == #"{"overrides":{"center":{}},"preset":"spectacle","schemaVersion":1}"#)
    }

    @Test func swappedCombosSurviveDecoding() throws {
        // Reachable through the UI: move Left Half away, give its combo to
        // Right Half, then give Right Half's old combo to Left Half.
        var settings = ShortcutSettings()
        let left = DefaultShortcuts.spectacle[.leftHalf]!, right = DefaultShortcuts.spectacle[.rightHalf]!
        #expect(settings.assign(KeyCombo(keyCode: 46, modifiers: [.control, .command]), to: .leftHalf) == nil)
        #expect(settings.assign(left, to: .rightHalf) == nil)
        #expect(settings.assign(right, to: .leftHalf) == nil)
        #expect(ShortcutSettings.decode(try settings.encoded()) == .loaded(settings))
    }

    @Test func newerVersionIsNotLoaded() {
        let data = Data(#"{"schemaVersion":2,"preset":"spectacle","overrides":{}}"#.utf8)
        #expect(ShortcutSettings.decode(data) == .newerVersion(2))
    }

    @Test func corruptDataFallsBack() {
        #expect(ShortcutSettings.decode(Data("not json".utf8)) == .corrupt)
    }

    @Test func unknownActionsAndPresetsAreSkipped() {
        let data = Data(#"{"schemaVersion":1,"preset":"future","overrides":{"teleport":{},"center":{}}}"#.utf8)
        var expected = ShortcutSettings()
        expected.setEnabled(false, for: .center)
        #expect(ShortcutSettings.decode(data) == .loaded(expected))
    }

    @Test func duplicateAndInvalidStoredCombosAreDisabled() {
        // center given Left Half's combo (duplicate), maximize given an Option-only combo (invalid).
        let data = Data(#"""
        {"schemaVersion":1,"preset":"spectacle","overrides":{
          "center":{"combo":{"keyCode":123,"modifiers":10}},
          "maximize":{"combo":{"keyCode":3,"modifiers":2}}}}
        """#.utf8)
        guard case .loaded(let settings) = ShortcutSettings.decode(data) else {
            Issue.record("expected loaded settings")
            return
        }
        #expect(!settings.isEnabled(.center))
        #expect(!settings.isEnabled(.maximize))
        #expect(settings.combo(for: .leftHalf) == DefaultShortcuts.spectacle[.leftHalf])
        #expect(Set(settings.effectiveBindings.values).count == settings.effectiveBindings.count)
    }
}
