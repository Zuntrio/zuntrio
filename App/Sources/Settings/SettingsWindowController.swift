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
    }

    /// Recording must never outlive the window, or global shortcuts would stay suspended.
    func windowWillClose(_ notification: Notification) {
        model.stopRecording()
    }

    func windowDidResignKey(_ notification: Notification) {
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
