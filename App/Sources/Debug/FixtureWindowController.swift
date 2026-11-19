#if DEBUG
import AppKit

/// Debug-only window with known size limits, used to prove that clamped
/// results are detected and reported instead of claimed as success.
@MainActor
final class FixtureWindowController {
    static let minimumContentSize = NSSize(width: 600, height: 400)
    static let maximumContentSize = NSSize(width: 1000, height: 700)

    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Zuntrio Test Window"
        window.isReleasedWhenClosed = false
        window.contentMinSize = Self.minimumContentSize
        window.contentMaxSize = Self.maximumContentSize

        let label = NSTextField(wrappingLabelWithString: """
            Test window. Content size is limited to \
            \(Int(Self.minimumContentSize.width))×\(Int(Self.minimumContentSize.height)) … \
            \(Int(Self.maximumContentSize.width))×\(Int(Self.maximumContentSize.height)). \
            Keep it focused and run an action from the Zuntrio menu or press ⌥⌘←.
            """)
        label.translatesAutoresizingMaskIntoConstraints = false
        if let content = window.contentView {
            content.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
                label.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            ])
        }
        return window
    }()

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
#endif
