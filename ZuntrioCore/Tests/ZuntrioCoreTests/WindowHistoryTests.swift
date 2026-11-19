import CoreGraphics
import Testing
@testable import ZuntrioCore

@Suite struct WindowHistoryTests {
    let a = CGRect(x: 0, y: 0, width: 100, height: 100)
    let b = CGRect(x: 0, y: 0, width: 200, height: 100)
    let c = CGRect(x: 0, y: 0, width: 300, height: 100)

    @Test func undoThenRedo() {
        var history = WindowHistory<String>()
        history.record(.init(before: a, after: b), for: "w")
        history.record(.init(before: b, after: c), for: "w")

        #expect(history.nextUndo(for: "w")?.before == b)
        history.didUndo(for: "w")
        #expect(history.nextUndo(for: "w")?.before == a)
        history.didUndo(for: "w")
        #expect(history.nextUndo(for: "w") == nil)

        #expect(history.nextRedo(for: "w")?.after == b)
        history.didRedo(for: "w")
        #expect(history.nextRedo(for: "w")?.after == c)
    }

    @Test func peekingDoesNotChangeHistory() {
        var history = WindowHistory<String>()
        history.record(.init(before: a, after: b), for: "w")
        _ = history.nextUndo(for: "w")
        _ = history.nextUndo(for: "w")
        #expect(history.nextUndo(for: "w")?.before == a)
        #expect(history.nextRedo(for: "w") == nil)
    }

    @Test func newActionClearsRedo() {
        var history = WindowHistory<String>()
        history.record(.init(before: a, after: b), for: "w")
        history.didUndo(for: "w")
        history.record(.init(before: a, after: c), for: "w")
        #expect(history.nextRedo(for: "w") == nil)
    }

    @Test func windowsAreIndependent() {
        var history = WindowHistory<String>()
        history.record(.init(before: a, after: b), for: "one")
        #expect(history.nextUndo(for: "two") == nil)
        history.didUndo(for: "two") // no-op
        #expect(history.nextUndo(for: "one")?.before == a)
    }

    @Test func depthIsBounded() {
        var history = WindowHistory<String>(depth: 3)
        for i in 0..<5 {
            let x = CGFloat(i)
            history.record(.init(before: CGRect(x: x, y: 0, width: 1, height: 1), after: CGRect(x: x + 1, y: 0, width: 1, height: 1)), for: "w")
        }
        var befores: [CGFloat] = []
        while let entry = history.nextUndo(for: "w") {
            befores.append(entry.before.minX)
            history.didUndo(for: "w")
        }
        #expect(befores == [4, 3, 2])
    }

    @Test func leastRecentlyUsedWindowsAreForgotten() {
        var history = WindowHistory<Int>(windowLimit: 2)
        history.record(.init(before: a, after: b), for: 1)
        history.record(.init(before: a, after: b), for: 2)
        history.didUndo(for: 1) // touching 1 makes 2 the least recent
        history.record(.init(before: a, after: b), for: 3)
        #expect(history.trackedWindowCount == 2)
        #expect(history.nextUndo(for: 2) == nil)
        #expect(history.nextRedo(for: 1) != nil)
        #expect(history.nextUndo(for: 3) != nil)
    }

    @Test func forgetRemovesAWindow() {
        var history = WindowHistory<String>()
        history.record(.init(before: a, after: b), for: "w")
        history.forget("w")
        #expect(history.nextUndo(for: "w") == nil)
        #expect(history.trackedWindowCount == 0)
    }
}

@Suite struct FittedFrameTests {
    let primary = DisplayGeometry(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                  visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 805))

    @Test func frameOnAConnectedDisplayIsUnchanged() {
        let onScreen = CGRect(x: 100, y: 100, width: 500, height: 400)
        #expect(DisplaySelection.fitted(onScreen, in: [primary]) == onScreen)
        let partlyOff = CGRect(x: 1300, y: 100, width: 500, height: 400)
        #expect(DisplaySelection.fitted(partlyOff, in: [primary]) == partlyOff)
    }

    @Test func frameFromADisconnectedDisplayMovesOntoTheNearestOne() {
        // Remembered on an external display to the right that is gone now.
        let lost = CGRect(x: 2000, y: 100, width: 800, height: 600)
        #expect(DisplaySelection.fitted(lost, in: [primary]) == CGRect(x: 640, y: 100, width: 800, height: 600))
    }

    @Test func oversizedLostFrameShrinksToFit() {
        let lost = CGRect(x: 3000, y: -2000, width: 2560, height: 1400)
        #expect(DisplaySelection.fitted(lost, in: [primary]) == primary.visibleFrame)
    }

    @Test func noDisplaysLeavesFrameAlone() {
        let rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        #expect(DisplaySelection.fitted(rect, in: []) == rect)
    }
}

@Suite struct HistoryActionTests {
    @Test func layoutEngineLeavesUndoRedoToHistory() {
        let screen = CGRect(x: 0, y: 25, width: 1440, height: 805)
        #expect(LayoutEngine.targetFrame(for: .undo, window: screen, visibleFrame: screen) == nil)
        #expect(LayoutEngine.targetFrame(for: .redo, window: screen, visibleFrame: screen) == nil)
        #expect(WindowAction.undo.isHistory && !WindowAction.center.isHistory)
    }

    @Test func undoRedoDefaults() {
        #expect(DefaultShortcuts.spectacle[.undo]?.displayString == "⌥⌘Z")
        #expect(DefaultShortcuts.spectacle[.redo]?.displayString == "⌥⇧⌘Z")
        #expect(DefaultShortcuts.alternative[.undo]?.displayString == "⌃⌥Z")
        #expect(DefaultShortcuts.alternative[.redo]?.displayString == "⌃⌥⇧Z")
    }
}
