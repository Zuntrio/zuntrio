#if DEBUG
import AppKit

/// UI-test mode (`--ui-testing`), used only by ZuntrioUITests. It keeps tests away
/// from the user's real setup: settings live in a throwaway store that is wiped at
/// launch, no global hotkeys are registered, no update checks run, and only the
/// window named by `--ui-testing-show settings|welcome` opens.
enum UITesting {
    static let isActive = CommandLine.arguments.contains("--ui-testing")

    static let suiteName = "app.zuntrio.Zuntrio.uitesting"

    /// Wiped on first use. Nil only if macOS refuses the suite name; then UI-test mode quits.
    /// `nonisolated(unsafe)`: UserDefaults is documented as thread-safe but isn't marked Sendable.
    nonisolated(unsafe) static let defaults: UserDefaults? = {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        return defaults
    }()

    static var windowToShow: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--ui-testing-show"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
}
#endif
