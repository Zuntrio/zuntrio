import CoreGraphics

/// Window actions supported by the layout engine.
///
/// Proof-of-concept subset; the remaining Spectacle-parity actions are added
/// in the core-geometry milestone.
public enum LayoutAction: String, Sendable, CaseIterable {
    case leftHalf
    case maximize
    case center

    public var displayName: String {
        switch self {
        case .leftHalf: "Left Half"
        case .maximize: "Maximize"
        case .center: "Center"
        }
    }
}

/// Pure geometry: given an action, the window's current frame and the target
/// display's visible frame (all in Accessibility coordinates), returns the
/// frame the window should get. No AppKit or Accessibility API use.
public enum LayoutEngine {
    /// Width fractions cycled by repeated half actions, in Spectacle's
    /// order (its code goes ½ → ⅔ → ⅓, despite its README saying ⅓ first).
    public static let cycleFractions: [CGFloat] = [1.0 / 2.0, 2.0 / 3.0, 1.0 / 3.0]

    /// How far (in points) a window may be from a layout rect and still count
    /// as "in" that layout for cycling purposes.
    public static let matchTolerance: CGFloat = 2

    public static func targetFrame(for action: LayoutAction, window: CGRect, visibleFrame: CGRect) -> CGRect {
        let screen = visibleFrame.standardized
        switch action {
        case .maximize:
            return screen.integral
        case .center:
            return centered(window.standardized.size, in: screen)
        case .leftHalf:
            return nextLeftFraction(window: window.standardized, screen: screen)
        }
    }

    // MARK: - Actions

    static func centered(_ size: CGSize, in screen: CGRect) -> CGRect {
        // Keep the size (as Spectacle does) but never exceed the usable area.
        let width = min(size.width, screen.width).rounded()
        let height = min(size.height, screen.height).rounded()
        let x = (screen.midX - width / 2).rounded()
        let y = (screen.midY - height / 2).rounded()
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func leftRect(fraction: CGFloat, in screen: CGRect) -> CGRect {
        CGRect(
            x: screen.minX,
            y: screen.minY,
            width: (screen.width * fraction).rounded(.down),
            height: screen.height
        )
    }

    static func nextLeftFraction(window: CGRect, screen: CGRect) -> CGRect {
        let candidates = cycleFractions.map { leftRect(fraction: $0, in: screen) }
        if let current = candidates.firstIndex(where: { approximatelyEqual($0, window) }) {
            return candidates[(current + 1) % candidates.count]
        }
        return candidates[0]
    }

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = matchTolerance) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }
}
