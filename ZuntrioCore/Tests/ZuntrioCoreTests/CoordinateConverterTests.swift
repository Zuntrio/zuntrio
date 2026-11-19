import CoreGraphics
import Testing
@testable import ZuntrioCore

/// Arrangement used throughout: a 1440×900 primary display (AppKit origin 0,0)
/// with optional secondary displays placed around it.
@Suite struct CoordinateConverterTests {
    let converter = CoordinateConverter(primaryScreenHeight: 900)

    @Test func primaryDisplayFrameMapsToOrigin() {
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect(ax == CGRect(x: 0, y: 0, width: 1440, height: 900))
    }

    @Test func primaryVisibleFrameExcludesMenuBarAtTop() {
        // Menu bar 25pt at the top, Dock 70pt at the bottom (AppKit space).
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 0, y: 70, width: 1440, height: 805))
        #expect(ax == CGRect(x: 0, y: 25, width: 1440, height: 805))
    }

    @Test func displayAbovePrimaryHasNegativeY() {
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 0, y: 900, width: 1920, height: 1080))
        #expect(ax == CGRect(x: 0, y: -1080, width: 1920, height: 1080))
    }

    @Test func displayBelowPrimaryStartsAtPrimaryHeight() {
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 200, y: -1080, width: 1920, height: 1080))
        #expect(ax == CGRect(x: 200, y: 900, width: 1920, height: 1080))
    }

    @Test func tallerDisplayToTheLeftBottomAligned() {
        // Bottom edges aligned in AppKit space; the taller display pokes above the primary.
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        #expect(ax == CGRect(x: -1920, y: -180, width: 1920, height: 1080))
    }

    @Test func portraitDisplayToTheRightStraddlingPrimary() {
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 1440, y: -500, width: 1080, height: 1920))
        #expect(ax == CGRect(x: 1440, y: -520, width: 1080, height: 1920))
    }

    @Test func fractionalScaledSizesSurvive() {
        // e.g. a "looks like 1512×982" scaled Retina mode with a half-point visible frame.
        let c = CoordinateConverter(primaryScreenHeight: 982)
        let ax = c.accessibilityRect(fromAppKit: CGRect(x: 0, y: 0, width: 1512, height: 949.5))
        #expect(ax == CGRect(x: 0, y: 32.5, width: 1512, height: 949.5))
    }

    @Test(arguments: [
        CGRect(x: 0, y: 70, width: 1440, height: 805),
        CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        CGRect(x: 1440, y: -500, width: 1080, height: 1920),
        CGRect(x: 123.5, y: -77.25, width: 640, height: 480),
    ])
    func roundTripIsIdentity(rect: CGRect) {
        let back = converter.appKitRect(fromAccessibility: converter.accessibilityRect(fromAppKit: rect))
        #expect(back == rect)
    }

    @Test func negativeSizeRectsAreStandardized() {
        let ax = converter.accessibilityRect(fromAppKit: CGRect(x: 100, y: 100, width: -50, height: -50))
        #expect(ax == CGRect(x: 50, y: 800, width: 50, height: 50))
    }
}
