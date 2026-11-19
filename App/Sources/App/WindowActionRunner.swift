import AppKit
import ZuntrioCore

/// What happened when an action ran. Carries geometry only, no window or app identity.
struct ActionReport: Sendable, Equatable {
    enum Result: Sendable, Equatable {
        /// The window ended up exactly where requested.
        case exact
        /// The app adjusted the frame (min/max size, character grid).
        case clamped
        /// A change was requested but the window didn't move or resize.
        case ignored
        /// The window is already where this action puts it, or as close as the app allows.
        case alreadyInPlace
        /// The action has nothing to do (single display, minimum size reached).
        case nothingToDo
        case failed(WindowAccessError)
    }

    let action: WindowAction
    let result: Result
    var before: CGRect?
    var requested: CGRect?
    var actual: CGRect?

    var summary: String {
        switch result {
        case .exact:
            "\(action.displayName): done"
        case .clamped:
            "\(action.displayName): app limited the size (asked \(Self.size(requested)), got \(Self.size(actual)))"
        case .ignored:
            "\(action.displayName): the app didn't move or resize the window (it may be at its size limit)"
        case .alreadyInPlace:
            "\(action.displayName): already in place"
        case .nothingToDo:
            switch action {
            case .undo: "Nothing to undo for this window"
            case .redo: "Nothing to redo for this window"
            default: "\(action.displayName): nothing to do"
            }
        case .failed(let error):
            "\(action.displayName): \(error.description)"
        }
    }

    var isPermissionMissing: Bool { result == .failed(.notTrusted) }

    private static func size(_ rect: CGRect?) -> String {
        guard let rect else { return "?" }
        return "\(Int(rect.width))×\(Int(rect.height))"
    }
}

/// Runs window actions: read → compute → set → read back → verify. Never
/// reports success unless the read-back matches.
///
/// Concurrency:
/// - Accessibility calls run on `AXWorker`'s background queue; the main thread
///   only reads displays and updates memory/history between those steps.
/// - Actions run strictly one after another, in the order pressed, each
///   starting from the window's current geometry.
/// - At most `maxQueued` actions wait at once; further presses are refused
///   (with a beep) so a hung app can't pile up work.
@MainActor
final class WindowActionRunner {
    static let maxQueued = 4

    private let provider: any WindowProviding
    private let worker = AXWorker()
    /// Debug/test only: act on this process instead of the frontmost app.
    private let targetPID: pid_t?

    private(set) var lastReport: ActionReport?
    private(set) var droppedCount = 0
    var onReport: ((ActionReport) -> Void)?

    /// Each queued action keeps the app that was frontmost when it was
    /// pressed, so a quick ⌘Tab afterwards can't redirect it.
    private var queue: [(action: WindowAction, pid: pid_t?, done: CheckedContinuation<ActionReport, Never>?)] = []
    private(set) var isBusy = false

    /// Last action applied, for cycling. Only one window is remembered:
    /// cycling needs consecutive presses on the same window.
    private var memory: (window: WindowID, layout: LayoutMemory)?
    /// Undo/redo history per window (in memory only, never persisted).
    private var history = WindowHistory<WindowID>()

    init(provider: any WindowProviding, targetPID: pid_t? = nil) {
        self.provider = provider
        self.targetPID = targetPID
    }

    /// Queues an action (shortcut or menu). Returns immediately.
    func perform(_ action: WindowAction) {
        enqueue(action, done: nil)
    }

    /// Queues an action and waits for its report.
    func performAndWait(_ action: WindowAction) async -> ActionReport {
        await withCheckedContinuation { continuation in
            enqueue(action, done: continuation)
        }
    }

    private func enqueue(_ action: WindowAction, done: CheckedContinuation<ActionReport, Never>?) {
        guard queue.count < Self.maxQueued else {
            droppedCount += 1
            let report = ActionReport(action: action, result: .failed(.busy))
            finish(report)
            done?.resume(returning: report)
            return
        }
        queue.append((action, targetPID ?? NSWorkspace.shared.frontmostApplication?.processIdentifier, done))
        guard !isBusy else { return }
        isBusy = true
        Task { await drain() }
    }

    private func drain() async {
        while !queue.isEmpty {
            let (action, pid, done) = queue.removeFirst()
            let report = await run(action, pid: pid)
            finish(report)
            done?.resume(returning: report)
        }
        isBusy = false
    }

    private func finish(_ report: ActionReport) {
        lastReport = report
        log(report)
        if report.result != .exact { NSSound.beep() }
        onReport?(report)
    }

    private func run(_ action: WindowAction, pid: pid_t?) async -> ActionReport {
        do throws(WindowAccessError) {
            guard AccessibilityPermission.isTrusted else { throw .notTrusted }
            guard let pid else { throw .noFrontmostApplication }
            let provider = self.provider
            let snapshot = try await worker.run { () throws(WindowAccessError) -> WindowSnapshot in
                let window = try provider.focusedWindow(pid: pid)
                return WindowSnapshot(window: window, frame: try window.frame())
            }
            let window = snapshot.window
            let before = snapshot.frame
            if action.isHistory {
                return try await runHistory(action, window: window, before: before)
            }

            let displays = DisplayProvider.current()
            guard let source = DisplaySelection.displayIndex(for: before, in: displays) else {
                throw .noDisplay
            }
            let remembered = memory.flatMap { $0.window == window.identity ? $0.layout : nil }
            guard let layout = LayoutEngine.layout(
                action, window: before, displays: displays, sourceDisplayIndex: source, memory: remembered
            ) else {
                return ActionReport(action: action, result: .nothingToDo, before: before)
            }
            let target = layout.frame

            // Skip the AX round trip when there is nothing to change: the
            // window is already there, or we asked for this exact frame last
            // time and the app settled where it is now.
            let alreadyThere = LayoutEngine.approximatelyEqual(target, before, tolerance: 1)
            let appSettled = remembered.map {
                LayoutEngine.approximatelyEqual($0.requestedFrame, target, tolerance: 1)
                    && LayoutEngine.approximatelyEqual($0.resultingFrame, before, tolerance: 1)
            } ?? false
            if alreadyThere || appSettled {
                return ActionReport(action: action, result: .alreadyInPlace, before: before, requested: target, actual: before)
            }

            let actual = try await worker.run { () throws(WindowAccessError) -> CGRect in
                try window.setFrame(target)
            }
            let outcome = FrameVerification.outcome(before: before, requested: target, actual: actual)
            // An ignored request is not remembered: the next press must try the
            // AX call again rather than report "already in place".
            if outcome.isAccepted {
                memory = (window.identity, LayoutMemory(
                    action: action, cycleIndex: layout.cycleIndex, requestedFrame: target, resultingFrame: actual
                ))
                if !LayoutEngine.approximatelyEqual(before, actual, tolerance: 1) {
                    history.record(.init(before: before, after: actual), for: window.identity)
                }
            }
            return ActionReport(action: action, result: Self.result(outcome), before: before, requested: target, actual: actual)
        } catch {
            return ActionReport(action: action, result: .failed(error))
        }
    }

    /// Undo restores the frame from before the window's last Zuntrio action;
    /// redo re-applies it. The history entry only moves once the frame was
    /// actually set, so a failed restore can be retried.
    private func runHistory(
        _ action: WindowAction, window: any ManagedWindow, before: CGRect
    ) async throws(WindowAccessError) -> ActionReport {
        let key = window.identity
        let isUndo = action == .undo
        guard let entry = isUndo ? history.nextUndo(for: key) : history.nextRedo(for: key) else {
            return ActionReport(action: action, result: .nothingToDo, before: before)
        }
        // The display the frame was on may have been disconnected since.
        let target = DisplaySelection.fitted(isUndo ? entry.before : entry.after, in: DisplayProvider.current())
        let commit = { [self] in
            if isUndo { history.didUndo(for: key) } else { history.didRedo(for: key) }
            memory = nil // the window left its layout cycle
        }

        if LayoutEngine.approximatelyEqual(target, before, tolerance: 1) {
            commit()
            return ActionReport(action: action, result: .alreadyInPlace, before: before, requested: target, actual: before)
        }
        let actual = try await worker.run { () throws(WindowAccessError) -> CGRect in
            try window.setFrame(target)
        }
        let outcome = FrameVerification.outcome(before: before, requested: target, actual: actual)
        // Keep the entry if the app ignored the restore, so undo/redo can be retried.
        if outcome.isAccepted { commit() }
        return ActionReport(action: action, result: Self.result(outcome), before: before, requested: target, actual: actual)
    }

    #if DEBUG
    /// Test harness only: sets the target window's frame directly.
    func setFrameDirectly(_ frame: CGRect) async throws(WindowAccessError) -> CGRect {
        guard let pid = targetPID ?? NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            throw .noFrontmostApplication
        }
        let provider = self.provider
        return try await worker.run { () throws(WindowAccessError) -> CGRect in
            try provider.focusedWindow(pid: pid).setFrame(frame)
        }
    }
    #endif

    private static func result(_ outcome: FrameOutcome) -> ActionReport.Result {
        switch outcome {
        case .exact: .exact
        case .clamped: .clamped
        case .ignored: .ignored
        case .alreadyClosest: .alreadyInPlace
        }
    }

    private func log(_ report: ActionReport) {
        let before = report.before.map { "\($0)" } ?? "-"
        let requested = report.requested.map { "\($0)" } ?? "-"
        let actual = report.actual.map { "\($0)" } ?? "-"
        Log.actions.info("""
            \(report.action.rawValue, privacy: .public) result=\(String(describing: report.result), privacy: .public) \
            before=\(before, privacy: .public) requested=\(requested, privacy: .public) actual=\(actual, privacy: .public)
            """)
    }
}

private struct WindowSnapshot: Sendable {
    let window: any ManagedWindow
    let frame: CGRect
}
