import CoreGraphics
import Testing
@testable import ZuntrioCore

/// 1440×900 primary with a 25pt menu bar and 70pt Dock, in AX coordinates.
let laptop = CGRect(x: 0, y: 25, width: 1440, height: 805)
/// Portrait display to the right of the primary (negative y in AX space).
let portrait = CGRect(x: 1440, y: -495, width: 1080, height: 1895)
/// Display to the left of the primary (negative x).
let leftDisplay = CGRect(x: -1920, y: -155, width: 1920, height: 1055)
/// A floating window in the middle of the laptop screen.
let floating = CGRect(x: 300, y: 200, width: 800, height: 600)

func target(_ action: LayoutAction, _ window: CGRect, on screen: CGRect = laptop, memory: LayoutMemory? = nil) -> CGRect? {
    LayoutEngine.targetFrame(for: action, window: window, visibleFrame: screen, memory: memory)
}

@Suite struct MaximizeAndCenterTests {
    @Test func maximizeFillsVisibleFrame() {
        #expect(target(.maximize, floating) == laptop)
        #expect(target(.maximize, floating, on: leftDisplay) == leftDisplay)
    }

    @Test func maximizeStaysInsideFractionalVisibleFrame() {
        let fractional = CGRect(x: 0, y: 32.5, width: 1512, height: 949.5)
        #expect(target(.maximize, floating, on: fractional) == CGRect(x: 0, y: 33, width: 1512, height: 949))
    }

    @Test func centerKeepsSize() {
        // midY = 427.5 → origin 127.5 rounds to 128.
        #expect(target(.center, floating) == CGRect(x: 320, y: 128, width: 800, height: 600))
    }

    @Test func centerClampsWindowLargerThanScreen() {
        #expect(target(.center, CGRect(x: 0, y: 0, width: 3000, height: 2000)) == laptop)
    }

    @Test(arguments: [laptop, portrait, leftDisplay])
    func centerIsContainedAndCentredOnAnyDisplay(screen: CGRect) throws {
        let frame = try #require(target(.center, floating, on: screen))
        #expect(screen.contains(frame))
        #expect(abs(frame.midX - screen.midX) <= 0.5)
        #expect(abs(frame.midY - screen.midY) <= 0.5)
        #expect(frame.size == floating.size)
    }
}

@Suite struct HalvesAndCornersTests {
    @Test func firstPressGivesHalves() {
        #expect(target(.leftHalf, floating) == CGRect(x: 0, y: 25, width: 720, height: 805))
        #expect(target(.rightHalf, floating) == CGRect(x: 720, y: 25, width: 720, height: 805))
        #expect(target(.topHalf, floating) == CGRect(x: 0, y: 25, width: 1440, height: 402))
        #expect(target(.bottomHalf, floating) == CGRect(x: 0, y: 428, width: 1440, height: 402))
    }

    @Test func firstPressGivesQuarters() {
        #expect(target(.upperLeft, floating) == CGRect(x: 0, y: 25, width: 720, height: 402))
        #expect(target(.upperRight, floating) == CGRect(x: 720, y: 25, width: 720, height: 402))
        #expect(target(.lowerLeft, floating) == CGRect(x: 0, y: 428, width: 720, height: 402))
        #expect(target(.lowerRight, floating) == CGRect(x: 720, y: 428, width: 720, height: 402))
    }

    /// Repeats an action on its own output, `count` times.
    func cycle(_ action: LayoutAction, _ count: Int, on screen: CGRect = laptop) -> [CGRect] {
        var frame = floating
        return (0..<count).compactMap { _ in
            guard let next = target(action, frame, on: screen) else { return nil }
            frame = next
            return next
        }
    }

    @Test func horizontalHalvesCycleHalfTwoThirdsThird() {
        #expect(cycle(.leftHalf, 4).map(\.width) == [720, 960, 480, 720])
        let right = cycle(.rightHalf, 4)
        #expect(right.map(\.width) == [720, 960, 480, 720])
        #expect(right.allSatisfy { $0.maxX == laptop.maxX })
    }

    @Test func verticalHalvesCycleOnHeight() {
        // 805 × ½ = 402, ⅔ = 536, ⅓ = 268 (floored).
        #expect(cycle(.topHalf, 4).map(\.height) == [402, 536, 268, 402])
        let bottom = cycle(.bottomHalf, 4)
        #expect(bottom.map(\.height) == [402, 536, 268, 402])
        #expect(bottom.allSatisfy { $0.maxY == laptop.maxY })
    }

    @Test func cornersCycleWidthOnlyHeightStaysHalf() {
        let frames = cycle(.lowerRight, 4)
        #expect(frames.map(\.width) == [720, 960, 480, 720])
        #expect(frames.allSatisfy { $0.height == 402 && $0.maxX == laptop.maxX && $0.maxY == laptop.maxY })
    }

    @Test func oddWidthsFloor() {
        let odd = CGRect(x: 0, y: 25, width: 1441, height: 805)
        #expect(target(.leftHalf, floating, on: odd)?.width == 720)
        #expect(target(.rightHalf, floating, on: odd) == CGRect(x: 721, y: 25, width: 720, height: 805))
    }

    @Test func portraitAndNegativeOriginDisplays() {
        #expect(target(.leftHalf, floating, on: portrait) == CGRect(x: 1440, y: -495, width: 540, height: 1895))
        #expect(target(.bottomHalf, floating, on: portrait) == CGRect(x: 1440, y: 453, width: 1080, height: 947))
        #expect(cycle(.leftHalf, 2, on: leftDisplay).map(\.width) == [960, 1280])
        #expect(target(.upperRight, floating, on: leftDisplay) == CGRect(x: -960, y: -155, width: 960, height: 527))
    }

    @Test func geometryMatchToleratesSmallDeviation() {
        let nearlyHalf = CGRect(x: 1, y: 25, width: 718, height: 805)
        #expect(target(.leftHalf, nearlyHalf)?.width == 960)
    }

    @Test func otherActionsLayoutDoesNotAdvanceCycle() {
        // A window in the right half pressed with Left Half starts at ½.
        let rightHalf = CGRect(x: 720, y: 25, width: 720, height: 805)
        #expect(target(.leftHalf, rightHalf)?.width == 720)
    }
}

/// The phase 2 bug: apps that adjust the frame (Terminal's character grid, a
/// maximum height) never matched a cycle candidate, so the cycle stalled.
@Suite struct CycleMemoryTests {
    let screen = CGRect(x: 0, y: 31, width: 1680, height: 957)
    let requestedHalf = CGRect(x: 0, y: 31, width: 840, height: 957)
    let terminalHalf = CGRect(x: 0, y: 31, width: 836, height: 947)

    var memory: LayoutMemory {
        LayoutMemory(action: .leftHalf, cycleIndex: 0, requestedFrame: requestedHalf, resultingFrame: terminalHalf)
    }

    @Test func withoutMemoryAGridSnappedWindowRestartsAtHalf() {
        #expect(target(.leftHalf, terminalHalf, on: screen) == requestedHalf)
    }

    @Test func memoryAdvancesTheCycle() {
        #expect(target(.leftHalf, terminalHalf, on: screen, memory: memory)
                == CGRect(x: 0, y: 31, width: 1120, height: 957))
    }

    @Test func memoryIsIgnoredIfTheWindowMovedSince() {
        let moved = terminalHalf.offsetBy(dx: 200, dy: 0)
        #expect(target(.leftHalf, moved, on: screen, memory: memory) == requestedHalf)
    }

    @Test func memoryOfADifferentActionIsIgnored() {
        var other = memory
        other.action = .rightHalf
        #expect(target(.leftHalf, terminalHalf, on: screen, memory: other) == requestedHalf)
    }

    @Test func memoryWrapsAtTheEndOfTheCycle() {
        var last = memory
        last.cycleIndex = 2
        #expect(target(.leftHalf, terminalHalf, on: screen, memory: last)?.width == 840)
    }
}

@Suite struct ThirdsTests {
    let columns = [
        CGRect(x: 0, y: 25, width: 480, height: 805),
        CGRect(x: 480, y: 25, width: 480, height: 805),
        CGRect(x: 960, y: 25, width: 480, height: 805),
    ]
    let rows = [
        CGRect(x: 0, y: 25, width: 1440, height: 268),
        CGRect(x: 0, y: 293, width: 1440, height: 269),
        CGRect(x: 0, y: 562, width: 1440, height: 268),
    ]

    @Test func ringIsThreeColumnsThenThreeRowsAndTiles() {
        #expect(LayoutEngine.thirdsRing(in: laptop) == columns + rows)
        #expect(rows[0].maxY == rows[1].minY && rows[1].maxY == rows[2].minY && rows[2].maxY == laptop.maxY)
    }

    @Test func nextThirdWalksTheRingAndWraps() {
        var frame = floating
        var seen: [CGRect] = []
        for _ in 0..<7 {
            frame = target(.nextThird, frame) ?? .null
            seen.append(frame)
        }
        #expect(seen == columns + rows + [columns[0]])
    }

    @Test func previousThirdGoesBackwardsAndWraps() {
        #expect(target(.previousThird, columns[1]) == columns[0])
        #expect(target(.previousThird, columns[0]) == rows[2])
    }

    @Test func unmatchedWindowStartsAtFirstColumnEitherWay() {
        #expect(target(.nextThird, floating) == columns[0])
        #expect(target(.previousThird, floating) == columns[0])
    }

    @Test func memoryIsSharedBetweenNextAndPrevious() {
        let clampedRow = CGRect(x: 0, y: 25, width: 1000, height: 268) // app capped the width
        let memory = LayoutMemory(action: .nextThird, cycleIndex: 3, requestedFrame: rows[0], resultingFrame: clampedRow)
        #expect(target(.previousThird, clampedRow, memory: memory) == columns[2])
        #expect(target(.nextThird, clampedRow, memory: memory) == rows[1])
    }
}

@Suite struct ResizeTests {
    @Test func largerGrowsAroundCentre() {
        #expect(target(.larger, floating) == CGRect(x: 285, y: 185, width: 830, height: 630))
    }

    @Test func smallerShrinksAroundCentre() {
        #expect(target(.smaller, floating) == CGRect(x: 315, y: 215, width: 770, height: 570))
    }

    @Test func edgeWithinFivePointsStaysPinned() {
        let nearLeft = CGRect(x: 4, y: 200, width: 800, height: 600)
        #expect(target(.larger, nearLeft) == CGRect(x: 0, y: 185, width: 834, height: 630))
        let leftHalf = CGRect(x: 0, y: 25, width: 720, height: 805)
        #expect(target(.smaller, leftHalf) == CGRect(x: 0, y: 40, width: 690, height: 775))
        #expect(target(.larger, leftHalf) == CGRect(x: 0, y: 25, width: 750, height: 805))
    }

    @Test func largerNeverExceedsTheScreen() throws {
        let nearRight = CGRect(x: 630, y: 200, width: 800, height: 600)
        let frame = try #require(target(.larger, nearRight))
        #expect(laptop.contains(frame))
        #expect(target(.larger, laptop) == nil) // already full screen: nothing to do
    }

    @Test func smallerOnMaximizedWindowShrinksAroundCentre() {
        #expect(target(.smaller, laptop) == CGRect(x: 15, y: 40, width: 1410, height: 775))
    }

    @Test func smallerStopsAtAQuarterOfTheScreen() {
        let small = CGRect(x: 300, y: 200, width: 380, height: 600) // 380 - 30 = 350 ≤ 1440 / 4
        #expect(target(.smaller, small) == nil)
    }
}

@Suite struct DisplayMoveTests {
    let primary = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: laptop)
    let external = DisplayGeometry(id: 2, frame: CGRect(x: 1440, y: -180, width: 1920, height: 1080),
                                   visibleFrame: CGRect(x: 1440, y: -155, width: 1920, height: 1055))
    let left = DisplayGeometry(id: 3, frame: CGRect(x: -1920, y: -180, width: 1920, height: 1080), visibleFrame: leftDisplay)

    @Test func singleDisplayHasNothingToDo() {
        #expect(LayoutEngine.layout(.nextDisplay, window: floating, displays: [primary], sourceDisplayIndex: 0) == nil)
    }

    @Test func leftHalfStaysALeftHalfOnTheNextDisplay() throws {
        let half = CGRect(x: 0, y: 25, width: 720, height: 805)
        let result = try #require(LayoutEngine.layout(.nextDisplay, window: half, displays: [primary, external], sourceDisplayIndex: 0))
        #expect(result.displayIndex == 1)
        #expect(result.frame == CGRect(x: 1440, y: -155, width: 960, height: 1055))
    }

    @Test func nextAndPreviousFollowSpatialOrderAndWrap() throws {
        // Deliberately unsorted input: external, primary, left.
        let displays = [external, primary, left]
        func next(_ from: Int, _ action: LayoutAction = .nextDisplay) -> Int? {
            LayoutEngine.layout(action, window: displays[from].visibleFrame, displays: displays, sourceDisplayIndex: from)?.displayIndex
        }
        #expect(next(2) == 1) // left → primary
        #expect(next(1) == 0) // primary → external
        #expect(next(0) == 2) // external wraps to left
        #expect(next(1, .previousDisplay) == 2)
        #expect(next(2, .previousDisplay) == 0)
    }

    @Test func movedWindowKeepsRelativePositionAndFits() throws {
        let result = try #require(LayoutEngine.layout(.nextDisplay, window: floating, displays: [primary, external], sourceDisplayIndex: 0))
        let target = external.visibleFrame
        #expect(target.contains(result.frame))
        let relX = (result.frame.minX - target.minX) / target.width
        #expect(abs(relX - (floating.minX - laptop.minX) / laptop.width) < 0.01)
    }

    @Test func partlyOffscreenWindowIsClampedOntoTarget() throws {
        let overhanging = CGRect(x: 1000, y: 25, width: 800, height: 805)
        let result = try #require(LayoutEngine.layout(.nextDisplay, window: overhanging, displays: [primary, external], sourceDisplayIndex: 0))
        #expect(external.visibleFrame.contains(result.frame))
    }

    @Test func movingToASmallerPortraitDisplayFits() throws {
        let tall = DisplayGeometry(id: 4, frame: CGRect(x: 1440, y: -520, width: 1080, height: 1920), visibleFrame: portrait)
        let result = try #require(LayoutEngine.layout(.nextDisplay, window: leftDisplay, displays: [left, tall], sourceDisplayIndex: 0))
        #expect(result.frame == portrait) // maximized stays maximized
    }

    @Test func invalidSourceIndexReturnsNil() {
        #expect(LayoutEngine.layout(.maximize, window: floating, displays: [primary], sourceDisplayIndex: 5) == nil)
    }
}
