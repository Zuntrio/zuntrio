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
        /// The window is already where this action puts it (or as close as the app allows).
        case alreadyInPlace
        /// The action has nothing to do (single display, minimum size reached).
        case nothingToDo
        case failed(String)
    }

    let action: LayoutAction
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
            "\(action.displayName): app ignored the change"
        case .alreadyInPlace:
            "\(action.displayName): already in place"
        case .nothingToDo:
            "\(action.displayName): nothing to do"
        case .failed(let reason):
            "\(action.displayName): \(reason)"
        }
    }

    private static func size(_ rect: CGRect?) -> String {
        guard let rect else { return "?" }
        return "\(Int(rect.width))×\(Int(rect.height))"
    }
}

/// Runs a layout action on the focused window: read → compute → set → read
/// back → verify. Never reports success unless the read-back matches.
///
/// Runs synchronously on the main thread. Every AX call is bounded by a 0.5 s
/// messaging timeout, and each press recomputes from the window's current
/// geometry, so rapid presses can't act on stale state.
@MainActor
final class WindowActionRunner {
    private let provider: any WindowProviding
    private(set) var lastReport: ActionReport?
    var onReport: ((ActionReport) -> Void)?

    /// Last action applied, for cycling. Only one window is remembered:
    /// cycling needs consecutive presses on the same window.
    private var memory: (window: AnyHashable, layout: LayoutMemory)?

    init(provider: any WindowProviding) {
        self.provider = provider
    }

    @discardableResult
    func perform(_ action: LayoutAction) -> ActionReport {
        let report = run(action)
        lastReport = report
        log(report)
        if report.result != .exact { NSSound.beep() }
        onReport?(report)
        return report
    }

    private func run(_ action: LayoutAction) -> ActionReport {
        do throws(WindowAccessError) {
            let window = try provider.focusedWindow()
            let before = try window.frame()

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

            let actual = try window.setFrame(target)
            memory = (window.identity, LayoutMemory(
                action: action, cycleIndex: layout.cycleIndex, requestedFrame: target, resultingFrame: actual
            ))

            let result: ActionReport.Result = switch FrameVerification.outcome(
                before: before, requested: target, actual: actual
            ) {
            case .exact: .exact
            case .clamped: .clamped
            case .ignored: .ignored
            }
            return ActionReport(action: action, result: result, before: before, requested: target, actual: actual)
        } catch {
            return ActionReport(action: action, result: .failed(error.description))
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
