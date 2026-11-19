import CoreGraphics
import Testing
@testable import ZuntrioCore

@Suite struct LayoutEngineTests {
    /// 1440×900 primary with a 25pt menu bar and 70pt Dock, in AX coordinates.
    let laptop = CGRect(x: 0, y: 25, width: 1440, height: 805)
    /// Portrait display to the right of the primary (negative y in AX space).
    let portrait = CGRect(x: 1440, y: -495, width: 1080, height: 1895)
    /// Display to the left of the primary (negative x).
    let leftDisplay = CGRect(x: -1920, y: -155, width: 1920, height: 1055)

    let window = CGRect(x: 300, y: 200, width: 800, height: 600)

    // MARK: Maximize

    @Test func maximizeFillsVisibleFrame() {
        #expect(LayoutEngine.targetFrame(for: .maximize, window: window, visibleFrame: laptop) == laptop)
        #expect(LayoutEngine.targetFrame(for: .maximize, window: window, visibleFrame: leftDisplay) == leftDisplay)
    }

    @Test func maximizeRoundsFractionalVisibleFrameOutward() {
        let fractional = CGRect(x: 0, y: 32.5, width: 1512, height: 949.5)
        #expect(LayoutEngine.targetFrame(for: .maximize, window: window, visibleFrame: fractional)
                == CGRect(x: 0, y: 32, width: 1512, height: 950))
    }

    // MARK: Center

    @Test func centerKeepsSize() {
        let target = LayoutEngine.targetFrame(for: .center, window: window, visibleFrame: laptop)
        // midY = 25 + 402.5 = 427.5 → 427.5 - 300 = 127.5 → rounds to 128.
        #expect(target == CGRect(x: 320, y: 128, width: 800, height: 600))
    }

    @Test func centerClampsWindowLargerThanScreen() {
        let huge = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        #expect(LayoutEngine.targetFrame(for: .center, window: huge, visibleFrame: laptop) == laptop)
    }

    @Test(arguments: [
        CGRect(x: 0, y: 25, width: 1440, height: 805),
        CGRect(x: 1440, y: -495, width: 1080, height: 1895),
        CGRect(x: -1920, y: -155, width: 1920, height: 1055),
    ])
    func centerIsContainedAndCentredOnAnyDisplay(screen: CGRect) {
        let target = LayoutEngine.targetFrame(for: .center, window: window, visibleFrame: screen)
        #expect(screen.contains(target))
        #expect(abs(target.midX - screen.midX) <= 0.5)
        #expect(abs(target.midY - screen.midY) <= 0.5)
        #expect(target.size == window.size)
    }

    // MARK: Left half cycling

    @Test func leftHalfFromArbitraryWindow() {
        #expect(LayoutEngine.targetFrame(for: .leftHalf, window: window, visibleFrame: laptop)
                == CGRect(x: 0, y: 25, width: 720, height: 805))
    }

    @Test func leftHalfCyclesHalfTwoThirdsThirdAndBack() {
        var frame = window
        var widths: [CGFloat] = []
        for _ in 0..<4 {
            frame = LayoutEngine.targetFrame(for: .leftHalf, window: frame, visibleFrame: laptop)
            widths.append(frame.width)
            #expect(frame.minX == laptop.minX)
            #expect(frame.minY == laptop.minY)
            #expect(frame.height == laptop.height)
        }
        #expect(widths == [720, 960, 480, 720])
    }

    @Test func leftHalfFloorsOddWidths() {
        let odd = CGRect(x: 0, y: 25, width: 1441, height: 805)
        #expect(LayoutEngine.targetFrame(for: .leftHalf, window: window, visibleFrame: odd).width == 720)
    }

    @Test func leftHalfOnPortraitDisplay() {
        #expect(LayoutEngine.targetFrame(for: .leftHalf, window: window, visibleFrame: portrait)
                == CGRect(x: 1440, y: -495, width: 540, height: 1895))
    }

    @Test func leftHalfOnNegativeOriginDisplayCycles() {
        let half = LayoutEngine.targetFrame(for: .leftHalf, window: window, visibleFrame: leftDisplay)
        #expect(half == CGRect(x: -1920, y: -155, width: 960, height: 1055))
        let twoThirds = LayoutEngine.targetFrame(for: .leftHalf, window: half, visibleFrame: leftDisplay)
        #expect(twoThirds.width == 1280)
    }

    @Test func cyclingToleratesSmallDeviation() {
        // App put the window 1pt off and 2pt narrower: still counts as the half.
        let nearlyHalf = CGRect(x: 1, y: 25, width: 718, height: 805)
        #expect(LayoutEngine.targetFrame(for: .leftHalf, window: nearlyHalf, visibleFrame: laptop).width == 960)
    }

    @Test func clampedWindowRestartsCycle() {
        // An app that refused to grow past 1000pt wide doesn't match ⅔ (960)… but a
        // window clamped at 1000 when ⅔ was requested is far from every candidate,
        // so the cycle restarts at ½. Documented behaviour for the proof of concept.
        let clamped = CGRect(x: 0, y: 25, width: 1000, height: 700)
        #expect(LayoutEngine.targetFrame(for: .leftHalf, window: clamped, visibleFrame: laptop).width == 720)
    }
}
