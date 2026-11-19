import AppKit
import ZuntrioCore

/// What happened when an action ran. Carries geometry only, no window or app identity.
struct ActionReport: Sendable, Equatable {
    enum Result: Sendable, Equatable {
        case exact
        case clamped
        case ignored
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
@MainActor
final class WindowActionRunner {
    private let provider: any WindowProviding
    private(set) var lastReport: ActionReport?
    var onReport: ((ActionReport) -> Void)?

    init(provider: any WindowProviding) {
        self.provider = provider
    }

    @discardableResult
    func perform(_ action: LayoutAction) -> ActionReport {
        let report = run(action)
        lastReport = report
        log(report)
        if case .exact = report.result {} else { NSSound.beep() }
        onReport?(report)
        return report
    }

    private func run(_ action: LayoutAction) -> ActionReport {
        do throws(WindowAccessError) {
            let window = try provider.focusedWindow()
            let before = try window.frame()

            let displays = DisplayProvider.current()
            guard let index = DisplaySelection.displayIndex(for: before, in: displays) else {
                throw WindowAccessError.noDisplay
            }
            let target = LayoutEngine.targetFrame(
                for: action, window: before, visibleFrame: displays[index].visibleFrame
            )
            let actual = try window.setFrame(target)

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
