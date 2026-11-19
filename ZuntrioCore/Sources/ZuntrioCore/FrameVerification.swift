import CoreGraphics

/// Result of comparing the frame we asked for with the frame read back
/// after setting it. Apps may clamp to their min/max size, snap to a
/// character grid, or ignore the request entirely.
public enum FrameOutcome: Sendable, Equatable {
    /// The window ended up where requested (within tolerance).
    case exact
    /// The window moved or resized, but not to the requested frame.
    case clamped(requested: CGRect, actual: CGRect)
    /// The window did not change at all although a different frame was requested.
    case ignored(requested: CGRect, actual: CGRect)
}

public enum FrameVerification {
    /// Default tolerance in points. AX positions are integral in practice;
    /// one point absorbs rounding differences between apps.
    public static let defaultTolerance: CGFloat = 1

    public static func outcome(
        before: CGRect,
        requested: CGRect,
        actual: CGRect,
        tolerance: CGFloat = defaultTolerance
    ) -> FrameOutcome {
        if matches(requested, actual, tolerance: tolerance) {
            return .exact
        }
        if matches(before, actual, tolerance: tolerance) {
            return .ignored(requested: requested, actual: actual)
        }
        return .clamped(requested: requested, actual: actual)
    }

    static func matches(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }
}
