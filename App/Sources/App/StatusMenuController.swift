import AppKit
import ZuntrioCore

/// Menu-bar item and its menu. The menu is rebuilt each time it opens so the
/// permission state is always current (permission can be revoked at any time).
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let runner: WindowActionRunner
    private let shortcutStatus: String
    #if DEBUG
    private lazy var fixture = FixtureWindowController()
    #endif

    init(runner: WindowActionRunner, shortcutStatus: String) {
        self.runner = runner
        self.shortcutStatus = shortcutStatus
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
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let trusted = AccessibilityPermission.isTrusted

        menu.addItem(info(trusted ? "Accessibility: granted" : "Accessibility: not granted"))
        if !trusted {
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
            menu.addItem(info("Or open \(AccessibilityPermission.manualPath)"))
        }

        menu.addItem(.separator())
        for action in LayoutAction.allCases {
            let menuItem = item(action.displayName, #selector(runAction(_:)))
            menuItem.representedObject = action.rawValue
            menu.addItem(menuItem)
        }

        menu.addItem(.separator())
        menu.addItem(info(shortcutStatus))
        menu.addItem(info("Last: " + (runner.lastReport?.summary ?? "none")))

        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(item("Show Test Window", #selector(showFixture)))
        #endif

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Zuntrio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
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

    @objc private func grantAccess() {
        // Shows the system prompt the first time; afterwards macOS stays quiet,
        // so we also open the settings pane directly.
        if !AccessibilityPermission.requestTrustPrompt() {
            AccessibilityPermission.openSystemSettings()
        }
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = LayoutAction(rawValue: raw) else { return }
        runner.perform(action)
    }

    #if DEBUG
    @objc private func showFixture() {
        fixture.show()
    }
    #endif
}
