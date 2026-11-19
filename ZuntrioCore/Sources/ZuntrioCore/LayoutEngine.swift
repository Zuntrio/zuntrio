import CoreGraphics

/// Every user-facing window action (Spectacle parity set). All but undo/redo
/// are computed by `LayoutEngine`; undo/redo are served by `WindowHistory`.
public enum WindowAction: String, Sendable, CaseIterable {
    case center
    case maximize
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case nextThird, previousThird
    case larger, smaller
    case nextDisplay, previousDisplay
    case undo, redo

    public var displayName: String {
        switch self {
        case .center: "Center"
        case .maximize: "Maximize"
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .upperLeft: "Upper Left"
        case .upperRight: "Upper Right"
        case .lowerLeft: "Lower Left"
        case .lowerRight: "Lower Right"
        case .nextThird: "Next Third"
        case .previousThird: "Previous Third"
        case .larger: "Make Larger"
        case .smaller: "Make Smaller"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .undo: "Undo"
        case .redo: "Redo"
        }
    }

    /// Undo/redo restore remembered frames instead of computing a layout.
    public var isHistory: Bool { self == .undo || self == .redo }

    var isThird: Bool { self == .nextThird || self == .previousThird }
}

/// What the app remembers about the last action applied to a window, so that
/// repeated presses keep cycling even when the app adjusted the frame (e.g.
/// Terminal snapping to its character grid, or a maximum window size).
public struct LayoutMemory: Sendable, Equatable {
    public var action: WindowAction
    public var cycleIndex: Int
    public var requestedFrame: CGRect
    public var resultingFrame: CGRect

    public init(action: WindowAction, cycleIndex: Int, requestedFrame: CGRect, resultingFrame: CGRect) {
        self.action = action
        self.cycleIndex = cycleIndex
        self.requestedFrame = requestedFrame
        self.resultingFrame = resultingFrame
    }
}

public struct LayoutResult: Sendable, Equatable {
    /// Target frame in Accessibility coordinates.
    public var frame: CGRect
    /// Display the frame is on (index into the displays passed in).
    public var displayIndex: Int
    /// Position in the action's cycle (0 for actions that don't cycle).
    public var cycleIndex: Int
}

/// Pure geometry. All frames are in Accessibility coordinates (top-left
/// origin, y down). No AppKit or Accessibility API use.
public enum LayoutEngine {
    /// Fractions cycled by repeated half/corner actions, in the order
    /// Spectacle's code uses (½ → ⅔ → ⅓).
    public static let cycleFractions: [CGFloat] = [1.0 / 2.0, 2.0 / 3.0, 1.0 / 3.0]
    /// How far (points) a window may be from a layout rect and still count as in it.
    public static let matchTolerance: CGFloat = 2
    /// Make Larger / Make Smaller step, applied to both width and height.
    public static let resizeStep: CGFloat = 30
    /// Edges this close (points) to a screen edge stay attached to it when resizing.
    public static let edgeSnapDistance: CGFloat = 5

    /// Computes where the window should go. Returns nil when the action has
    /// nothing to do (e.g. next display with one display, or shrinking below
    /// the minimum).
    ///
    /// - Parameters:
    ///   - window: the window's current frame.
    ///   - displays: all displays.
    ///   - sourceDisplayIndex: the display the window is on (see `DisplaySelection`).
    ///   - memory: the last action applied to this same window, if any.
    public static func layout(
        _ action: WindowAction,
        window: CGRect,
        displays: [DisplayGeometry],
        sourceDisplayIndex: Int,
        memory: LayoutMemory? = nil
    ) -> LayoutResult? {
        guard displays.indices.contains(sourceDisplayIndex) else { return nil }
        let window = window.standardized
        let screen = displays[sourceDisplayIndex].visibleFrame.standardized
        guard screen.width > 0, screen.height > 0 else { return nil }

        func onSource(_ frame: CGRect, cycle: Int = 0) -> LayoutResult {
            LayoutResult(frame: frame, displayIndex: sourceDisplayIndex, cycleIndex: cycle)
        }

        switch action {
        case .maximize:
            return onSource(snapped(screen))

        case .center:
            return onSource(centered(window.size, in: screen))

        case .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .upperLeft, .upperRight, .lowerLeft, .lowerRight:
            let candidates = cycleFractions.map { fractionRect(action, fraction: $0, in: screen) }
            let current = currentIndex(in: candidates, window: window, memory: memory) { $0 == action }
            let next = current.map { ($0 + 1) % candidates.count } ?? 0
            return onSource(candidates[next], cycle: next)

        case .nextThird, .previousThird:
            let ring = thirdsRing(in: screen)
            let current = currentIndex(in: ring, window: window, memory: memory) { $0.isThird }
            let step = action == .nextThird ? 1 : ring.count - 1
            // Spectacle: an unmatched window goes to the first third either way.
            let next = current.map { ($0 + step) % ring.count } ?? 0
            return onSource(ring[next], cycle: next)

        case .larger, .smaller:
            return resized(window, in: screen, larger: action == .larger).map { onSource($0) }

        case .nextDisplay, .previousDisplay:
            guard displays.count > 1 else { return nil }
            let order = DisplayOrdering.order(displays)
            guard let position = order.firstIndex(of: sourceDisplayIndex) else { return nil }
            let offset = action == .nextDisplay ? 1 : order.count - 1
            let target = order[(position + offset) % order.count]
            let frame = moved(window, from: screen, to: displays[target].visibleFrame.standardized)
            return LayoutResult(frame: frame, displayIndex: target, cycleIndex: 0)

        case .undo, .redo:
            return nil // handled by WindowHistory
        }
    }

    /// Single-display convenience used by tests and simple callers.
    public static func targetFrame(
        for action: WindowAction, window: CGRect, visibleFrame: CGRect, memory: LayoutMemory? = nil
    ) -> CGRect? {
        let display = DisplayGeometry(id: 0, frame: visibleFrame, visibleFrame: visibleFrame)
        return layout(action, window: window, displays: [display], sourceDisplayIndex: 0, memory: memory)?.frame
    }

    // MARK: - Cycling

    /// Where the window currently is in a cycle. Memory wins when it describes
    /// the same cycle and the window hasn't moved since; otherwise fall back to
    /// matching the window's geometry against the candidates.
    static func currentIndex(
        in candidates: [CGRect], window: CGRect, memory: LayoutMemory?, sameCycle: (WindowAction) -> Bool
    ) -> Int? {
        if let memory, sameCycle(memory.action), candidates.indices.contains(memory.cycleIndex),
           approximatelyEqual(memory.resultingFrame, window) {
            return memory.cycleIndex
        }
        return candidates.firstIndex { approximatelyEqual($0, window) }
    }

    // MARK: - Geometry

    static func fractionRect(_ action: WindowAction, fraction: CGFloat, in s: CGRect) -> CGRect {
        let width = (s.width * fraction).rounded(.down)
        let height = (s.height * fraction).rounded(.down)
        let halfHeight = (s.height / 2).rounded(.down)
        let rect: CGRect = switch action {
        case .leftHalf: CGRect(x: s.minX, y: s.minY, width: width, height: s.height)
        case .rightHalf: CGRect(x: s.maxX - width, y: s.minY, width: width, height: s.height)
        case .topHalf: CGRect(x: s.minX, y: s.minY, width: s.width, height: height)
        case .bottomHalf: CGRect(x: s.minX, y: s.maxY - height, width: s.width, height: height)
        // Corners cycle the width only; the height stays half (as in Spectacle).
        case .upperLeft: CGRect(x: s.minX, y: s.minY, width: width, height: halfHeight)
        case .upperRight: CGRect(x: s.maxX - width, y: s.minY, width: width, height: halfHeight)
        case .lowerLeft: CGRect(x: s.minX, y: s.maxY - halfHeight, width: width, height: halfHeight)
        case .lowerRight: CGRect(x: s.maxX - width, y: s.maxY - halfHeight, width: width, height: halfHeight)
        default: s
        }
        return snapped(rect)
    }

    /// Six thirds: three columns left → right, then three rows top → bottom
    /// (Spectacle's ring, independent of display orientation).
    static func thirdsRing(in s: CGRect) -> [CGRect] {
        let columns = (0..<3).map { i in
            CGRect(x: s.minX + s.width * CGFloat(i) / 3, y: s.minY, width: s.width / 3, height: s.height)
        }
        let rows = (0..<3).map { i in
            CGRect(x: s.minX, y: s.minY + s.height * CGFloat(i) / 3, width: s.width, height: s.height / 3)
        }
        return (columns + rows).map(snapped)
    }

    static func centered(_ size: CGSize, in screen: CGRect) -> CGRect {
        let width = min(size.width, screen.width)
        let height = min(size.height, screen.height)
        return snapped(CGRect(x: screen.midX - width / 2, y: screen.midY - height / 2, width: width, height: height))
    }

    /// Spectacle-style incremental resize: grow/shrink by `resizeStep` around
    /// the centre, but keep edges that touch the screen edge attached to it.
    /// Never exceeds the screen. Returns nil if nothing would change or the
    /// window would shrink to a quarter of the screen or less.
    static func resized(_ w: CGRect, in s: CGRect, larger: Bool) -> CGRect? {
        let (x0, x1) = resizedAxis(w.minX, w.maxX, s.minX, s.maxX, larger: larger)
        let (y0, y1) = resizedAxis(w.minY, w.maxY, s.minY, s.maxY, larger: larger)
        let result = snapped(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))

        if !larger, result.width <= s.width / 4 || result.height <= s.height / 4 {
            return nil
        }
        if approximatelyEqual(result, w, tolerance: 0.5) {
            return nil
        }
        return result
    }

    private static func resizedAxis(
        _ start: CGFloat, _ end: CGFloat, _ low: CGFloat, _ high: CGFloat, larger: Bool
    ) -> (CGFloat, CGFloat) {
        let pinnedLow = abs(start - low) <= edgeSnapDistance
        let pinnedHigh = abs(end - high) <= edgeSnapDistance
        let step = resizeStep
        var newStart: CGFloat
        var newEnd: CGFloat

        if larger {
            switch (pinnedLow, pinnedHigh) {
            case (true, true): (newStart, newEnd) = (low, high)
            case (true, false): (newStart, newEnd) = (low, end + step)
            case (false, true): (newStart, newEnd) = (start - step, high)
            case (false, false): (newStart, newEnd) = (start - step / 2, end + step / 2)
            }
            newStart = max(newStart, low)
            newEnd = min(newEnd, high)
        } else {
            switch (pinnedLow, pinnedHigh) {
            case (true, false): (newStart, newEnd) = (low, end - step)
            case (false, true): (newStart, newEnd) = (start + step, high)
            case (true, true), (false, false): (newStart, newEnd) = (start + step / 2, end - step / 2)
            }
        }
        if newEnd < newStart { newEnd = newStart }
        return (newStart, newEnd)
    }

    /// Moves a window to another display keeping its position and size
    /// relative to the visible frame (a left-half window stays a left half),
    /// clamped to fit.
    static func moved(_ w: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let scaleX = target.width / source.width
        let scaleY = target.height / source.height
        let width = min(w.width * scaleX, target.width)
        let height = min(w.height * scaleY, target.height)
        var x = target.minX + (w.minX - source.minX) * scaleX
        var y = target.minY + (w.minY - source.minY) * scaleY
        x = min(max(x, target.minX), target.maxX - width)
        y = min(max(y, target.minY), target.maxY - height)
        return snapped(CGRect(x: x, y: y, width: width, height: height))
    }

    /// Rounds each edge to whole points, so adjacent layouts tile without gaps
    /// and results stay inside fractional visible frames.
    static func snapped(_ r: CGRect) -> CGRect {
        let minX = r.minX.rounded(), minY = r.minY.rounded()
        let maxX = r.maxX.rounded(), maxY = r.maxY.rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = matchTolerance) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }
}
