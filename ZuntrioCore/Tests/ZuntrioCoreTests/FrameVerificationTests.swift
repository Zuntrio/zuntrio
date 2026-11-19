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
}
