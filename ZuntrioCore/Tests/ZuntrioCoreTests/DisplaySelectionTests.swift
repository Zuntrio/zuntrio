import CoreGraphics
import Testing
@testable import ZuntrioCore

@Suite struct DisplaySelectionTests {
    // AX space: primary at origin, a portrait display to the right, one above.
    let primary = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                  visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 805))
    let portrait = DisplayGeometry(id: 2, frame: CGRect(x: 1440, y: -520, width: 1080, height: 1920),
                                   visibleFrame: CGRect(x: 1440, y: -495, width: 1080, height: 1895))
    let above = DisplayGeometry(id: 3, frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
                                visibleFrame: CGRect(x: 0, y: -1055, width: 1920, height: 1055))

    var displays: [DisplayGeometry] { [primary, portrait, above] }

    @Test func emptyDisplayListReturnsNil() {
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 0, y: 0, width: 10, height: 10), in: []) == nil)
    }

    @Test func windowFullyOnOneDisplay() {
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 100, y: 100, width: 400, height: 300), in: displays) == 0)
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 1500, y: 0, width: 400, height: 300), in: displays) == 1)
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 100, y: -800, width: 400, height: 300), in: displays) == 2)
    }

    @Test func straddlingWindowPicksLargestOverlap() {
        // 300pt on primary, 100pt on the portrait display.
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 1140, y: 100, width: 400, height: 300), in: displays) == 0)
        // 100pt on primary, 300pt on the portrait display.
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 1340, y: 100, width: 400, height: 300), in: displays) == 1)
    }

    @Test func offscreenWindowPicksNearestDisplay() {
        // Far below everything, closest to the primary's centre.
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 500, y: 5000, width: 100, height: 100), in: displays) == 0)
        // Far right, closest to the portrait display.
        #expect(DisplaySelection.displayIndex(for: CGRect(x: 6000, y: 0, width: 100, height: 100), in: displays) == 1)
    }
}

@Suite struct DisplayOrderingTests {
    func display(_ id: UInt32, x: CGFloat, y: CGFloat) -> DisplayGeometry {
        let frame = CGRect(x: x, y: y, width: 100, height: 100)
        return DisplayGeometry(id: id, frame: frame, visibleFrame: frame)
    }

    @Test func leftToRightThenTopToBottomThenID() {
        let displays = [
            display(5, x: 100, y: 0),
            display(4, x: -100, y: 0),
            display(3, x: 100, y: -100),
            display(2, x: 0, y: 0),
            display(1, x: 0, y: 0),
        ]
        #expect(DisplayOrdering.order(displays) == [1, 4, 3, 2, 0])
    }
}
