import CoreGraphics

/// Failures when finding or manipulating a window. Messages never contain
/// window titles or app names.
enum WindowAccessError: Error, Equatable, Sendable, CustomStringConvertible {
    case notTrusted
    case noFrontmostApplication
    case noFocusedWindow
    case unsupportedWindow(reason: String)
    case attributeNotSettable(attribute: String)
    case accessibilityFailure(operation: String, code: Int32)
    case noDisplay
    /// Too many actions waiting (e.g. the target app isn't responding).
    case busy
    /// The app didn't answer within the messaging timeout (kAXErrorCannotComplete).
    case appNotResponding

    var description: String {
        switch self {
        case .notTrusted: "Accessibility permission not granted"
        case .noFrontmostApplication: "No frontmost application"
        case .noFocusedWindow: "No focused window"
        case .unsupportedWindow(let reason): "Unsupported window (\(reason))"
        case .attributeNotSettable(let attribute): "Window does not allow changing \(attribute)"
        case .accessibilityFailure(let operation, let code): "\(operation) failed (AXError \(code))"
        case .noDisplay: "No display found"
        case .busy: "Still working on earlier actions"
        case .appNotResponding: "App isn't responding"
        }
    }
}

/// Identity of a window for the lifetime of the window. Wraps the window's
/// AXUIElement: an immutable CF object whose CFEqual/CFHash identify the same
/// window across lookups and are safe to call from any thread. Not persisted
/// and never logged.
struct WindowID: Hashable, @unchecked Sendable {
    let base: AnyHashable
}

/// A window whose frame can be read and set, in Accessibility coordinates.
///
/// Implementations make blocking Accessibility calls: use them only on the
/// `AXWorker` queue, never on the main thread.
protocol ManagedWindow: Sendable {
    var identity: WindowID { get }
    func frame() throws(WindowAccessError) -> CGRect
    /// Applies `target` and returns the frame read back afterwards. The read-back
    /// value is the truth; it may differ from `target` if the app clamps it.
    func setFrame(_ target: CGRect) throws(WindowAccessError) -> CGRect
}

/// Finds the window to act on in a given app. Blocking; `AXWorker` queue only.
protocol WindowProviding: Sendable {
    func focusedWindow(pid: pid_t) throws(WindowAccessError) -> any ManagedWindow
}
