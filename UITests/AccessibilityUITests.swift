import XCTest

/// What VoiceOver reads in Settings and the welcome window. The app runs in UI-test
/// mode: no global hotkeys, throwaway settings, and only the requested window opens.
@MainActor
final class AccessibilityUITests: XCTestCase {
    /// Every window action, as shown in Settings, with its Spectacle default spoken.
    private static let spectacleDefaults: [(String, String)] = [
        ("Center", "Option Command C"),
        ("Maximize", "Option Command F"),
        ("Left Half", "Option Command Left Arrow"),
        ("Right Half", "Option Command Right Arrow"),
        ("Top Half", "Option Command Up Arrow"),
        ("Bottom Half", "Option Command Down Arrow"),
        ("Undo", "Option Command Z"),
        ("Redo", "Option Shift Command Z"),
    ]

    private let glyphs = CharacterSet(charactersIn: "⌃⌥⇧⌘←→↑↓↩⌫⎋⇥")

    private func launch(showing window: String) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-show", window]
        app.launch()
        return app
    }

    func testSettingsShortcutButtonsNameTheirActionAndSpeakTheKeys() throws {
        let app = launch(showing: "settings")
        let window = app.windows["Zuntrio Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Settings window didn't open")

        for (action, spoken) in Self.spectacleDefaults {
            let button = window.buttons["Shortcut for \(action)"]
            XCTAssertTrue(button.exists, "No button labelled 'Shortcut for \(action)'")
            XCTAssertEqual(button.value as? String, spoken, "Spoken shortcut for \(action)")
        }

        // Every shortcut button has a label naming its action and a value without glyphs.
        let shortcutButtons = window.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Shortcut for '"))
        XCTAssertEqual(shortcutButtons.count, 18, "One shortcut button per window action")
        for button in shortcutButtons.allElementsBoundByIndex {
            let value = button.value as? String ?? ""
            XCTAssertFalse(value.isEmpty, "\(button.label) has no spoken value")
            XCTAssertNil(value.rangeOfCharacter(from: glyphs), "\(button.label) speaks a glyph: \(value)")
        }
        app.terminate()
    }

    func testRecordingStateIsAnnounced() throws {
        let app = launch(showing: "settings")
        let window = app.windows["Zuntrio Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        window.buttons["Shortcut for Center"].click()
        let recording = window.buttons["Recording shortcut for Center"]
        XCTAssertTrue(recording.waitForExistence(timeout: 5), "Recording state isn't announced")

        window.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(window.buttons["Shortcut for Center"].waitForExistence(timeout: 5), "Escape didn't end recording")
        XCTAssertEqual(window.buttons["Shortcut for Center"].value as? String, "Option Command C", "Escape changed the shortcut")
        app.terminate()
    }

    func testSettingsGeneralControls() throws {
        let app = launch(showing: "settings")
        let window = app.windows["Zuntrio Settings"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        let updates = window.checkBoxes["Check for updates automatically"]
        XCTAssertTrue(updates.exists, "Update check toggle missing")
        XCTAssertEqual(updates.value as? Int, 0, "Automatic update checks must be off by default")
        XCTAssertTrue(window.checkBoxes["Launch Zuntrio at login"].exists)
        XCTAssertTrue(window.checkBoxes["Center"].exists, "Action checkboxes are named after the action")
        app.terminate()
    }

    func testWelcomeWindowReadsShortcutsAsWords() throws {
        let app = launch(showing: "welcome")
        let window = app.windows["Welcome to Zuntrio"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Welcome window didn't open")

        let leftHalf = window.descendants(matching: .any)["Left Half: Option Command Left Arrow"]
        XCTAssertTrue(leftHalf.exists, "'Try it' rows should be read as one item with the keys in words")

        let privacy = window.staticTexts.matching(NSPredicate(format: "value CONTAINS 'unless you check for updates'"))
        XCTAssertGreaterThan(privacy.count, 0, "Privacy text must mention the update check")
        app.terminate()
    }
}
