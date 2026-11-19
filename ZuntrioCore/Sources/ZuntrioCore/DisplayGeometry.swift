import CoreGraphics

/// A display described in Accessibility coordinates (top-left origin, y down).
public struct DisplayGeometry: Sendable, Equatable {
    /// Opaque identifier (the `CGDirectDisplayID` in the app layer).
    public let id: UInt32
    /// Full display bounds.
    public let frame: CGRect
    /// Usable area excluding the menu bar and Dock. Layouts target this.
    public let visibleFrame: CGRect

    public init(id: UInt32, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

public enum DisplaySelection {
    /// Returns the index of the display a window belongs to: the one that
    /// shares the largest area with the window. If the window intersects no
    /// display (e.g. it was left on a disconnected screen), the display whose
    /// centre is closest to the window's centre is chosen. Returns nil only
    /// when `displays` is empty.
    public static func displayIndex(for window: CGRect, in displays: [DisplayGeometry]) -> Int? {
        guard !displays.isEmpty else { return nil }

        var bestIndex: Int?
        var bestArea: CGFloat = 0
        for (index, display) in displays.enumerated() {
            let overlap = display.frame.intersection(window)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                bestIndex = index
            }
        }
        if let bestIndex { return bestIndex }

        let center = CGPoint(x: window.midX, y: window.midY)
        return displays.indices.min { a, b in
            squaredDistance(center, displays[a].frame) < squaredDistance(center, displays[b].frame)
        }
    }

    private static func squaredDistance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = point.x - rect.midX
        let dy = point.y - rect.midY
        return dx * dx + dy * dy
    }
}

/// Deterministic order for next/previous display: left to right by the
/// display's left edge, then top to bottom, then by identifier. This avoids
/// depending on the order `NSScreen.screens` happens to return.
public enum DisplayOrdering {
    public static func order(_ displays: [DisplayGeometry]) -> [Int] {
        displays.indices.sorted { a, b in
            let da = displays[a].frame, db = displays[b].frame
            if da.minX != db.minX { return da.minX < db.minX }
            if da.minY != db.minY { return da.minY < db.minY }
            return displays[a].id < displays[b].id
        }
    }
}
