import Testing
@testable import ZuntrioCore

@Suite struct DefaultShortcutTests {
    let map = DefaultShortcuts.spectacle

    @Test func everyActionHasADefault() {
        #expect(Set(map.keys) == Set(LayoutAction.allCases))
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
