import AppKit
import ZuntrioCore

/// Snapshot of connected displays in Accessibility coordinates. Read fresh
/// for every action so display changes are always reflected.
@MainActor
enum DisplayProvider {
    static func current() -> [DisplayGeometry] {
        let screens = NSScreen.screens
        // The primary display (menu bar) has AppKit origin (0, 0). It is also
        // `screens.first` in practice; the origin check makes it explicit.
        guard let primary = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first else {
            return []
        }
        let converter = CoordinateConverter(primaryScreenHeight: primary.frame.height)
        return screens.map { screen in
            DisplayGeometry(
                id: displayID(of: screen),
                frame: converter.accessibilityRect(fromAppKit: screen.frame),
                visibleFrame: converter.accessibilityRect(fromAppKit: screen.visibleFrame)
            )
        }
    }

    private static func displayID(of screen: NSScreen) -> UInt32 {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
