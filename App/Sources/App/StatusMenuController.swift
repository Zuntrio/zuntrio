import AppKit
import ZuntrioCore

/// Menu-bar item and its menu. The menu is rebuilt each time it opens so the
/// permission and shortcut state are always current.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runner: WindowActionRunner
    private let shortcuts: ShortcutController
    private let monitor: AccessibilityMonitor
    private let showWelcome: () -> Void
    private let showSettings: () -> Void
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

    init(runner: WindowActionRunner, shortcuts: ShortcutController, monitor: AccessibilityMonitor,
         showWelcome: @escaping () -> Void, showSettings: @escaping () -> Void) {
        self.runner = runner
        self.shortcuts = shortcuts
        self.monitor = monitor
        self.showWelcome = showWelcome
        self.showSettings = showSettings
        super.init()

        if let button = statusItem.button {
            // Placeholder SF Symbol until the owner approves a menu-bar icon.
            button.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Zuntrio")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        trustChanged(monitor.isTrusted)
    }

    /// Dims the menu-bar icon while Accessibility access is missing.
    func trustChanged(_ trusted: Bool) {
        statusItem.button?.appearsDisabled = !trusted
        statusItem.button?.toolTip = trusted ? "Zuntrio" : "Zuntrio needs Accessibility access"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        monitor.refresh()
        let trusted = monitor.isTrusted

        menu.addItem(info(trusted ? "Accessibility: granted" : "Accessibility: not granted"))
        if !trusted {
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
            menu.addItem(info("Or open \(AccessibilityPermission.manualPath)"))
        }

        for section in Self.sections {
            menu.addItem(.separator())
            for action in section {
                let menuItem = actionItem(action, title: action.displayName, selector: #selector(runAction(_:)))
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())
        let settingsItem = item("Settings…", #selector(openSettings))
        settingsItem.keyEquivalent = ","
        menu.addItem(settingsItem)
        if !shortcuts.failures.isEmpty {
            menu.addItem(info("⚠︎ \(shortcuts.failures.count) shortcut(s) in use by another app"))
        }
        if !shortcuts.systemConflicts.isEmpty {
            menu.addItem(info("⚠︎ \(shortcuts.systemConflicts.count) shortcut(s) also used by macOS"))
        }
        menu.addItem(info("Last: " + (runner.lastReport?.summary ?? "none")))

        menu.addItem(.separator())
        menu.addItem(item("Welcome & Permissions…", #selector(openWelcome)))
        menu.addItem(item("About Zuntrio", #selector(showAbout)))
        #if DEBUG
        menu.addItem(item("Show Test Window", #selector(showFixture)))
        #endif

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Zuntrio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: - Items

    /// An action item with its global shortcut (and any problem) in a
    /// right-aligned column. Shortcuts are shown as text, not key equivalents:
    /// key equivalents would only fire while the menu is open.
    private func actionItem(_ action: WindowAction, title: String, selector: Selector) -> NSMenuItem {
        var detail = shortcuts.combo(for: action)?.displayString ?? "—"
        if shortcuts.failures[action] != nil {
            detail += "  ⚠︎ in use by another app"
        } else if shortcuts.systemConflicts.contains(action) {
            detail += "  ⚠︎ also a macOS shortcut"
        }
        let text = "\(title)\t\(detail)"
        let menuItem = item(text, selector)
        menuItem.representedObject = action.rawValue
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .left, location: 160)]
        menuItem.attributedTitle = NSAttributedString(
            string: text, attributes: [.paragraphStyle: style, .font: NSFont.menuFont(ofSize: 0)]
        )
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
