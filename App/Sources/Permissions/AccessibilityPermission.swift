import AppKit
import ApplicationServices

/// Accessibility (TCC) trust state. Zuntrio only reads trust and points the
/// user to System Settings; it never tries to grant or bypass the permission.
enum AccessibilityPermission {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show its standard "would like to control this computer"
    /// prompt if the app is not yet trusted. Returns the current trust state.
    @discardableResult
    static func requestTrustPrompt() -> Bool {
        // The string value of `kAXTrustedCheckOptionPrompt`. The global is
        // imported as a mutable var, which Swift 6 strict concurrency rejects.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Manual path shown alongside the deep link in case the link stops working.
    static let manualPath = "System Settings → Privacy & Security → Accessibility"

    /// Opens Privacy & Security → Accessibility. The URL is not formally
    /// documented by Apple; on macOS 27 the legacy pane identifier is mapped to
    /// the Privacy & Security extension. Returns false if it could not be opened.
    @MainActor
    @discardableResult
    static func openSystemSettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            Log.permissions.error("Could not open Accessibility settings deep link")
        }
        return opened
    }
}
