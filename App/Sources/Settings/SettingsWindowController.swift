import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        model.reload()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        Log.settings.info("Settings shown; app active=\(NSApp.isActive), window key=\(window.isKeyWindow)")
    }

    /// Recording must never outlive the window, or shortcuts would stay in capture mode.
    func windowWillClose(_ notification: Notification) {
        model.stopRecording()
    }

    func windowDidResignKey(_ notification: Notification) {
        Log.settings.info("Settings window resigned key")
        model.stopRecording()
    }

    func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Zuntrio Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
