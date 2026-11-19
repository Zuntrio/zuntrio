import AppKit
import ApplicationServices

/// Upper bound for any single AX call. Without it a hung target app can block
/// the main thread for the system default (~6 s).
private let messagingTimeout: Float = 0.5

/// Finds the focused window of the frontmost application.
@MainActor
struct AXWindowProvider: WindowProviding {
    func focusedWindow() throws(WindowAccessError) -> any ManagedWindow {
        guard AccessibilityPermission.isTrusted else { throw .notTrusted }
        guard let app = NSWorkspace.shared.frontmostApplication else { throw .noFrontmostApplication }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)

        let windowValue: CFTypeRef
        do {
            windowValue = try AX.copyAttribute(appElement, kAXFocusedWindowAttribute)
        } catch .accessibilityFailure(_, let code) where code == AXError.noValue.rawValue {
            throw .noFocusedWindow
        }
        guard let window = AX.element(from: windowValue) else { throw .noFocusedWindow }
        AXUIElementSetMessagingTimeout(window, messagingTimeout)

        try AX.rejectUnsupported(window)
        return AXWindow(element: window, application: appElement)
    }
}

@MainActor
final class AXWindow: ManagedWindow {
    private let element: AXUIElement
    private let application: AXUIElement

    init(element: AXUIElement, application: AXUIElement) {
        self.element = element
        self.application = application
    }

    func frame() throws(WindowAccessError) -> CGRect {
        let position = try AX.copyPoint(element, kAXPositionAttribute)
        let size = try AX.copySize(element, kAXSizeAttribute)
        return CGRect(origin: position, size: size)
    }

    func setFrame(_ target: CGRect) throws(WindowAccessError) -> CGRect {
        guard AX.isSettable(element, kAXPositionAttribute) else {
            throw .attributeNotSettable(attribute: "position")
        }
        guard AX.isSettable(element, kAXSizeAttribute) else {
            throw .attributeNotSettable(attribute: "size")
        }

        // Some apps (notably Chromium/Electron) animate or partly ignore frame
        // changes while AXEnhancedUserInterface is on (it is enabled by assistive
        // tech such as VoiceOver). Turn it off for the change and restore it after.
        let restoreEnhancedUI = AX.disableEnhancedUserInterface(application)
        defer {
            if restoreEnhancedUI { AX.setEnhancedUserInterface(application, true) }
        }

        // Size → position → size. The first resize lets the window fit where it
        // is going; macOS may refuse a size that doesn't fit the current
        // display. The final resize applies the size again once the window is in
        // place (moving it onto a different display can change what's allowed).
        try AX.setSize(element, target.size)
        try AX.setPoint(element, target.origin)
        try AX.setSize(element, target.size)

        return try frame()
    }
}

/// Thin, typed wrappers over the C Accessibility API.
@MainActor
enum AX {
    static func copyAttribute(_ element: AXUIElement, _ attribute: String) throws(WindowAccessError) -> CFTypeRef {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value else {
            let code = error == .success ? AXError.noValue.rawValue : error.rawValue
            throw .accessibilityFailure(operation: "Read \(attribute)", code: code)
        }
        return value
    }

    static func element(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func copyPoint(_ element: AXUIElement, _ attribute: String) throws(WindowAccessError) -> CGPoint {
        let value = try copyAXValue(element, attribute, type: .cgPoint)
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { throw decodeFailure(attribute) }
        return point
    }

    static func copySize(_ element: AXUIElement, _ attribute: String) throws(WindowAccessError) -> CGSize {
        let value = try copyAXValue(element, attribute, type: .cgSize)
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { throw decodeFailure(attribute) }
        return size
    }

    private static func copyAXValue(
        _ element: AXUIElement, _ attribute: String, type: AXValueType
    ) throws(WindowAccessError) -> AXValue {
        let value = try copyAttribute(element, attribute)
        guard CFGetTypeID(value) == AXValueGetTypeID() else { throw decodeFailure(attribute) }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == type else { throw decodeFailure(attribute) }
        return axValue
    }

    private static func decodeFailure(_ attribute: String) -> WindowAccessError {
        .accessibilityFailure(operation: "Decode \(attribute)", code: AXError.illegalArgument.rawValue)
    }

    static func setPoint(_ element: AXUIElement, _ point: CGPoint) throws(WindowAccessError) {
        var point = point
        guard let value = AXValueCreate(.cgPoint, &point) else {
            throw .accessibilityFailure(operation: "Encode position", code: AXError.illegalArgument.rawValue)
        }
        try set(element, kAXPositionAttribute, value)
    }

    static func setSize(_ element: AXUIElement, _ size: CGSize) throws(WindowAccessError) {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            throw .accessibilityFailure(operation: "Encode size", code: AXError.illegalArgument.rawValue)
        }
        try set(element, kAXSizeAttribute, value)
    }

    private static func set(_ element: AXUIElement, _ attribute: String, _ value: CFTypeRef) throws(WindowAccessError) {
        let error = AXUIElementSetAttributeValue(element, attribute as CFString, value)
        guard error == .success else {
            throw .accessibilityFailure(operation: "Set \(attribute)", code: error.rawValue)
        }
    }

    static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        if error != .success {
            Log.accessibility.debug("IsSettable \(attribute, privacy: .public) returned AXError \(error.rawValue)")
        }
        return error == .success && settable.boolValue
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return unsafeDowncast(value, to: CFString.self) as String
    }

    /// Rejects windows we must not or cannot move: sheets, dialogs, panels,
    /// minimized windows and native full-screen windows. If an app doesn't
    /// report a subrole at all we let it through; the read-back will tell us
    /// whether the move worked.
    static func rejectUnsupported(_ window: AXUIElement) throws(WindowAccessError) {
        if let subrole = string(window, kAXSubroleAttribute), subrole != kAXStandardWindowSubrole {
            throw .unsupportedWindow(reason: "subrole \(subrole)")
        }
        if bool(window, kAXMinimizedAttribute) == true {
            throw .unsupportedWindow(reason: "minimized")
        }
        // "AXFullScreen" has no public constant; native full-screen windows live
        // in their own Space and can't be repositioned.
        if bool(window, "AXFullScreen") == true {
            throw .unsupportedWindow(reason: "full screen")
        }
    }

    private static let enhancedUserInterface = "AXEnhancedUserInterface"

    /// Returns true if the attribute was on and has been turned off.
    static func disableEnhancedUserInterface(_ app: AXUIElement) -> Bool {
        guard bool(app, enhancedUserInterface) == true else { return false }
        return setEnhancedUserInterface(app, false)
    }

    @discardableResult
    static func setEnhancedUserInterface(_ app: AXUIElement, _ enabled: Bool) -> Bool {
        let value: CFBoolean = enabled ? kCFBooleanTrue : kCFBooleanFalse
        let error = AXUIElementSetAttributeValue(app, enhancedUserInterface as CFString, value)
        if error != .success {
            Log.accessibility.error("Setting AXEnhancedUserInterface=\(enabled) failed: AXError \(error.rawValue)")
        }
        return error == .success
    }
}
