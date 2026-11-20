import Testing
@testable import ZuntrioCore

@Suite struct DefaultShortcutTests {
    let map = DefaultShortcuts.spectacle

    @Test func everyActionHasADefault() {
        #expect(Set(map.keys) == Set(WindowAction.allCases))
    }

    @Test func defaultsAreUnique() {
        #expect(Set(map.values).count == map.count)
    }

    @Test func everyDefaultUsesCommandOrControl() {
        // macOS 15.0 rejected Option-only / Option+Shift-only hotkeys.
        #expect(map.values.allSatisfy { !$0.modifiers.isDisjoint(with: [.command, .control]) })
    }

    @Test func displayStringsMatchSpectacle() {
        #expect(map[.leftHalf]?.displayString == "⌥⌘←")
        #expect(map[.center]?.displayString == "⌥⌘C")
        #expect(map[.lowerRight]?.displayString == "⌃⇧⌘→")
        #expect(map[.larger]?.displayString == "⌃⌥⇧→")
        #expect(map[.previousDisplay]?.displayString == "⌃⌥⌘←")
    }
}

@Suite struct SpokenShortcutTests {
    @Test func spokenDescriptions() {
        #expect(KeyCombo(keyCode: KeyCombo.Key.leftArrow, modifiers: [.option, .command]).spokenDescription == "Option Command Left Arrow")
        #expect(KeyCombo(keyCode: KeyCombo.Key.c, modifiers: [.command, .option]).spokenDescription == "Option Command C")
        #expect(KeyCombo(keyCode: KeyCombo.Key.rightArrow, modifiers: [.control, .option, .shift, .command]).spokenDescription
            == "Control Option Shift Command Right Arrow")
        #expect(KeyCombo(keyCode: KeyCombo.Key.returnKey, modifiers: [.control, .option]).spokenDescription == "Control Option Return")
        #expect(KeyCombo(keyCode: KeyCombo.Key.equal, modifiers: [.control, .option]).spokenDescription == "Control Option Equals")
        #expect(KeyCombo(keyCode: KeyCombo.Key.minus, modifiers: [.control, .option]).spokenDescription == "Control Option Minus")
        #expect(KeyCombo(keyCode: 49, modifiers: [.command]).spokenDescription == "Command Space")
        #expect(KeyCombo(keyCode: 99, modifiers: [.command]).spokenDescription == "Command Key 99")
    }

    @Test func everySymbolKeyHasASpokenName() {
        for (code, name) in KeyCombo.keyNames where !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " }) {
            #expect(KeyCombo.spokenKeyNames[code] != nil, "No spoken name for \(name)")
        }
    }

    @Test func defaultsAreAllSpeakable() {
        for combo in Array(DefaultShortcuts.spectacle.values) + Array(DefaultShortcuts.alternative.values) {
            #expect(!combo.spokenDescription.contains(where: { "⌃⌥⇧⌘←→↑↓↩⌫⎋⇥".contains($0) }))
        }
    }
}
