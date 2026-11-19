import CoreGraphics
import Testing
@testable import ZuntrioCore

@Suite struct FrameVerificationTests {
    let before = CGRect(x: 300, y: 200, width: 800, height: 600)
    let requested = CGRect(x: 0, y: 25, width: 720, height: 805)

    @Test func exactMatch() {
        #expect(FrameVerification.outcome(before: before, requested: requested, actual: requested) == .exact)
    }

    @Test func withinToleranceIsExact() {
        let actual = requested.offsetBy(dx: 1, dy: -1)
        #expect(FrameVerification.outcome(before: before, requested: requested, actual: actual) == .exact)
    }

    @Test func minimumSizeClampIsReported() {
        let actual = CGRect(x: 0, y: 25, width: 900, height: 805)
        #expect(FrameVerification.outcome(before: before, requested: requested, actual: actual)
                == .clamped(requested: requested, actual: actual))
    }

    @Test func unchangedWindowIsReportedAsIgnored() {
        #expect(FrameVerification.outcome(before: before, requested: requested, actual: before)
                == .ignored(requested: requested, actual: before))
    }

    @Test func requestingCurrentFrameIsExactNotIgnored() {
        #expect(FrameVerification.outcome(before: requested, requested: requested, actual: requested) == .exact)
    }

    @Test func gridSnappedWindowThatCannotGetCloserIsAlreadyClosest() {
        // Terminal near full screen: Make Larger asks for 4×10 pt more; the grid can't grow.
        let terminal = CGRect(x: 0, y: 31, width: 1676, height: 947)
        let larger = CGRect(x: 0, y: 31, width: 1680, height: 957)
        #expect(FrameVerification.outcome(before: terminal, requested: larger, actual: terminal)
                == .alreadyClosest(requested: larger, actual: terminal))
    }

    @Test func unchangedWindowFarFromRequestIsStillIgnored() {
        let far = CGRect(x: 0, y: 25, width: 1100, height: 805) // 300 pt wider than before
        #expect(FrameVerification.outcome(before: before, requested: far, actual: before)
                == .ignored(requested: far, actual: before))
    }

    @Test func onlyIgnoredOutcomesAreNotAccepted() {
        let r = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(FrameOutcome.exact.isAccepted)
        #expect(FrameOutcome.clamped(requested: r, actual: r).isAccepted)
        #expect(FrameOutcome.alreadyClosest(requested: r, actual: r).isAccepted)
        #expect(!FrameOutcome.ignored(requested: r, actual: r).isAccepted)
    }
}
