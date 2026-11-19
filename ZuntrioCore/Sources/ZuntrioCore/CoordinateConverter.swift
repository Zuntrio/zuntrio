import CoreGraphics

/// Converts rectangles between the two global coordinate spaces macOS uses.
///
/// - AppKit (`NSScreen.frame`, `visibleFrame`): origin at the bottom-left of the
///   primary display, y grows upward.
/// - Accessibility (`kAXPositionAttribute`): origin at the top-left of the
///   primary display, y grows downward.
///
/// The primary display is the one whose AppKit frame origin is (0, 0). Both
/// spaces share the x axis, so only y is flipped around the primary display's
/// height. The transform is its own inverse.
///
/// This is the only place the conversion happens. Everything downstream of
/// `DisplayProvider` works in Accessibility coordinates.
public struct CoordinateConverter: Sendable, Equatable {
    public let primaryScreenHeight: CGFloat

    public init(primaryScreenHeight: CGFloat) {
        self.primaryScreenHeight = primaryScreenHeight
    }

    public func accessibilityRect(fromAppKit rect: CGRect) -> CGRect {
        flip(rect)
    }

    public func appKitRect(fromAccessibility rect: CGRect) -> CGRect {
        flip(rect)
    }

    private func flip(_ rect: CGRect) -> CGRect {
        let r = rect.standardized
        return CGRect(x: r.minX, y: primaryScreenHeight - r.maxY, width: r.width, height: r.height)
    }
}
