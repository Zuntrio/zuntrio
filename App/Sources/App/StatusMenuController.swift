import AppKit
import ZuntrioCore

/// Menu-bar item and its menu. The menu is rebuilt each time it opens so the
/// permission, shortcut and disable state are always current.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runner: WindowActionRunner
    private let shortcuts: ShortcutController
    private let pause: PauseController
    private let monitor: AccessibilityMonitor
    private let showWelcome: () -> Void
    private let showSettings: () -> Void
    /// The app that was in front when the menu opened (target of "Disable in …").
    private var menuTargetApp: PauseSettings.DisabledApp?
    #if DEBUG
    private lazy var fixture = FixtureWindowController()
    #endif

    /// Menu sections, in Spectacle's order.
    private static let sections: [[WindowAction]] = [
        [.center, .maximize],
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.upperLeft, .upperRight, .lowerLeft, .lowerRight],
        [.nextThird, .previousThird],
        [.larger, .smaller],
        [.nextDisplay, .previousDisplay],
        [.undo, .redo],
    ]

    init(runner: WindowActionRunner, shortcuts: ShortcutController, pause: PauseController,
         monitor: AccessibilityMonitor, showWelcome: @escaping () -> Void, showSettings: @escaping () -> Void) {
        self.runner = runner
        self.shortcuts = shortcuts
        self.pause = pause
        self.monitor = monitor
        self.showWelcome = showWelcome
        self.showSettings = showSettings
        super.init()

        if let button = statusItem.button {
            // Template image: macOS tints it for light and dark menu bars.
            let image = NSImage(named: "MenuBarIcon")
                ?? NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
            image?.isTemplate = true
            image?.accessibilityDescription = "Zuntrio"
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshIcon()
    }

    /// Dims the menu-bar icon while Accessibility access is missing or the
    /// shortcuts are switched off.
    func refreshIcon() {
        let trusted = monitor.isTrusted
        statusItem.button?.appearsDisabled = !trusted || !pause.shortcutsActive
        statusItem.button?.toolTip = if !trusted {
            "Zuntrio needs Accessibility access"
        } else if !pause.shortcutsActive {
            "Zuntrio shortcuts are off"
        } else {
            "Zuntrio"
        }
    }

    // MARK: - Building the menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        monitor.refresh()
        pause.evaluate()
        refreshIcon()
        menuTargetApp = pause.frontmostOtherApp

        if !monitor.isTrusted {
            menu.addItem(info("Accessibility access needed"))
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
            menu.addItem(.separator())
        }
        if let until = pause.settings.pausedUntil, pause.isPausedNow {
            menu.addItem(info("Shortcuts off until \(Self.format(until))"))
            menu.addItem(item("Turn Shortcuts Back On", #selector(resume)))
            menu.addItem(.separator())
        } else if let app = menuTargetApp, pause.settings.isDisabled(bundleID: app.bundleID) {
            menu.addItem(info("Shortcuts off in “\(app.name)”"))
            let on = item("Turn Back On in “\(app.name)”", #selector(toggleApp))
            menu.addItem(on)
            menu.addItem(.separator())
        }

        for (index, section) in Self.sections.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for action in section {
                menu.addItem(actionItem(action))
            }
        }

        if let report = runner.lastReport, report.result != .exact {
            menu.addItem(.separator())
            let last = info(Self.truncated(report.summary, to: 44))
            last.toolTip = report.summary
            menu.addItem(last)
        }
        if !shortcuts.failures.isEmpty || !shortcuts.systemConflicts.isEmpty {
            let count = Set(shortcuts.failures.keys).union(shortcuts.systemConflicts).count
            let warning = info("\(count) shortcut\(count == 1 ? "" : "s") unavailable — see Settings")
            warning.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Warning")
            menu.addItem(warning)
        }

        menu.addItem(.separator())
        if !pause.isPausedNow {
            let disable = NSMenuItem(title: "Disable Shortcuts", action: nil, keyEquivalent: "")
            disable.submenu = disableMenu()
            menu.addItem(disable)
        }
        let settingsItem = item("Settings…", #selector(openSettings))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        menu.addItem(item("Welcome & Permissions…", #selector(openWelcome)))
        menu.addItem(item("About Zuntrio", #selector(showAbout)))
        #if DEBUG
        menu.addItem(item("Show Test Window", #selector(showFixture)))
        #endif

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Zuntrio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// Shortcuts are global hotkeys; the menu only displays them. Pressing one
    /// while the menu is open must not trigger the item a second time.
    func menuHasKeyEquivalent(
        _ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>,
        action: UnsafeMutablePointer<Selector?>
    ) -> Bool {
        false
    }

    private func disableMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("For 1 Hour", #selector(disableForAnHour)))
        menu.addItem(item("For Several Hours…", #selector(disableForHours)))
        if let app = menuTargetApp {
            menu.addItem(.separator())
            let appItem = item("In “\(app.name)”", #selector(toggleApp))
            appItem.state = pause.settings.isDisabled(bundleID: app.bundleID) ? .on : .off
            appItem.toolTip = "Always off while \(app.name) is in front"
            menu.addItem(appItem)
        }
        return menu
    }

    private func actionItem(_ action: WindowAction) -> NSMenuItem {
        let menuItem = item(action.displayName, #selector(runAction(_:)))
        menuItem.representedObject = action.rawValue
        MenuKeyEquivalent.apply(shortcuts.combo(for: action), to: menuItem)
        if shortcuts.failures[action] != nil {
            menuItem.toolTip = "This shortcut is in use by another app. Change it in Settings."
        } else if shortcuts.systemConflicts.contains(action) {
            menuItem.toolTip = "This shortcut is also a macOS keyboard shortcut."
        }
        return menuItem
    }

    private func item(_ title: String, _ selector: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    private func info(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    private func action(of sender: NSMenuItem) -> WindowAction? {
        (sender.representedObject as? String).flatMap(WindowAction.init(rawValue:))
    }

    static func format(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func truncated(_ text: String, to length: Int) -> String {
        text.count <= length ? text : String(text.prefix(length - 1)) + "…"
    }

    // MARK: - Handlers

    @objc private func grantAccess() {
        // Shows the system prompt the first time; afterwards macOS stays quiet,
        // so we also open the settings pane directly.
        if !AccessibilityPermission.requestTrustPrompt() {
            AccessibilityPermission.openSystemSettings()
        }
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        guard let action = action(of: sender) else { return }
        runner.perform(action)
    }

    @objc private func disableForAnHour() {
        pause.pause(hours: 1)
    }

    @objc private func disableForHours() {
        guard let hours = HoursPrompt.ask() else { return }
        pause.pause(hours: hours)
    }

    @objc private func resume() {
        pause.resume()
    }

    @objc private func toggleApp() {
        guard let app = menuTargetApp else { return }
        if pause.settings.isDisabled(bundleID: app.bundleID) {
            pause.enable(bundleID: app.bundleID)
        } else {
            pause.disable(app)
        }
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func openWelcome() {
        showWelcome()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    #if DEBUG
    @objc private func showFixture() {
        fixture.show()
    }
    #endif
}

/// Small dialog asking for how many hours to disable the shortcuts.
@MainActor
enum HoursPrompt {
    static func ask() -> Int? {
        let alert = NSAlert()
        // A menu-bar-only app's alerts don't pick up its icon by themselves.
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Disable Zuntrio's shortcuts for how long?"
        alert.informativeText = "Until then, the shortcuts go to the app you're using."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 140, height: 26), pullsDown: false)
        for hours in PauseSettings.hourRange {
            popup.addItem(withTitle: hours == 1 ? "1 hour" : "\(hours) hours")
            popup.lastItem?.tag = hours
        }
        popup.selectItem(withTag: 2)
        alert.accessoryView = popup
        alert.addButton(withTitle: "Disable")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return popup.selectedItem?.tag
    }
}
