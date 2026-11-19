import CoreGraphics

/// Failures when finding or manipulating a window. Messages never contain
/// window titles or app names.
enum WindowAccessError: Error, Equatable, CustomStringConvertible {
    case notTrusted
    case noFrontmostApplication
    case noFocusedWindow
    case unsupportedWindow(reason: String)
    case attributeNotSettable(attribute: String)
    case accessibilityFailure(operation: String, code: Int32)
    case noDisplay

    var description: String {
        switch self {
        case .notTrusted: "Accessibility permission not granted"
        case .noFrontmostApplication: "No frontmost application"
        case .noFocusedWindow: "No focused window"
        case .unsupportedWindow(let reason): "Unsupported window (\(reason))"
        case .attributeNotSettable(let attribute): "Window does not allow changing \(attribute)"
        case .accessibilityFailure(let operation, let code): "\(operation) failed (AXError \(code))"
        case .noDisplay: "No display found"
        }
    }
}

/// A window whose frame can be read and set, in Accessibility coordinates.
@MainActor
protocol ManagedWindow {
    /// Stable identity for the lifetime of the window (used to remember the
    /// last action applied to it). Not persisted and never logged.
    var identity: AnyHashable { get }
    func frame() throws(WindowAccessError) -> CGRect
    /// Applies `target` and returns the frame read back afterwards. The read-back
    /// value is the truth; it may differ from `target` if the app clamps it.
    func setFrame(_ target: CGRect) throws(WindowAccessError) -> CGRect
}

@MainActor
protocol WindowProviding {
    func focusedWindow() throws(WindowAccessError) -> any ManagedWindow
}
