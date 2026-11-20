import AppKit
import ZuntrioCore

/// Fetches the release list. Behind a protocol so the checker can run against a fake.
protocol ReleaseFetching: Sendable {
    func fetchReleases() async throws -> Data
}

/// The only network request Zuntrio makes (ADR-0007): one HTTPS GET to the GitHub
/// Releases API, sent when the user clicks "Check for Updates…" or has turned on
/// automatic checks. It sends no identifiers, cookies or query data about the user
/// or the Mac, only a generic User-Agent naming the Zuntrio version.
struct GitHubReleaseFetcher: ReleaseFetching {
    static let endpoint = URL(string: "https://api.github.com/repos/Zuntrio/zuntrio/releases?per_page=30")

    enum FetchError: Error {
        case badURL
        case httpStatus(Int)
    }

    func fetchReleases() async throws -> Data {
        guard let url = Self.endpoint else { throw FetchError.badURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Zuntrio/\(ReleaseInfo.version)", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FetchError.httpStatus(status) }
        return data
    }
}

/// Checks GitHub for a newer Zuntrio, on request or (if the user opted in) at most
/// once a day. It only reports; it never downloads or installs anything.
@MainActor
final class UpdateChecker {
    enum Outcome: Equatable {
        case available(UpdatePolicy.Update)
        case upToDate
        case failed
    }

    static let automaticKey = "checkForUpdatesAutomatically"
    static let lastCheckKey = "lastUpdateCheck"

    private let fetcher: ReleaseFetching
    private let defaults: UserDefaults
    private var timer: Timer?

    /// The newest update found by the last successful check, if any.
    private(set) var available: UpdatePolicy.Update?
    /// Called on the main actor when `available` changes.
    var onChange: (() -> Void)?

    init(fetcher: ReleaseFetching = GitHubReleaseFetcher(), defaults: UserDefaults = .standard) {
        self.fetcher = fetcher
        self.defaults = defaults
    }

    /// Off by default. Turning it on checks right away if a check is due.
    var checksAutomatically: Bool {
        get { defaults.bool(forKey: Self.automaticKey) }
        set {
            defaults.set(newValue, forKey: Self.automaticKey)
            Log.updates.info("Automatic update checks \(newValue ? "on" : "off", privacy: .public)")
            if newValue { checkIfDue() }
        }
    }

    /// Starts the hourly look at whether an automatic check is due. Nothing is sent
    /// unless automatic checks are on and the last check is a day old.
    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
        timer.tolerance = 5 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        checkIfDue()
    }

    func checkIfDue(now: Date = Date()) {
        let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date
        guard UpdatePolicy.isAutomaticCheckDue(enabled: checksAutomatically, lastCheck: lastCheck, now: now) else { return }
        Task { _ = await check() }
    }

    /// One check. The attempt time is recorded even when it fails, so automatic
    /// checks never run more than once a day.
    func check() async -> Outcome {
        guard let current = ReleaseInfo.current else {
            Log.updates.error("Update check skipped: the app's own version doesn't parse")
            return .failed
        }
        defaults.set(Date(), forKey: Self.lastCheckKey)
        do {
            let releases = try UpdatePolicy.decodeReleases(try await fetcher.fetchReleases())
            let update = UpdatePolicy.newestUpdate(for: current, in: releases)
            if update != available {
                available = update
                onChange?()
            }
            Log.updates.info("Update check: \(update?.version.description ?? "up to date", privacy: .public)")
            return update.map(Outcome.available) ?? .upToDate
        } catch {
            Log.updates.error("Update check failed: \(Self.describe(error), privacy: .public)")
            return .failed
        }
    }

    /// Error kind only: no URLs, headers or response bodies in the log.
    private static func describe(_ error: Error) -> String {
        switch error {
        case let error as URLError: return "URLError \(error.code.rawValue)"
        case GitHubReleaseFetcher.FetchError.httpStatus(let status): return "HTTP \(status)"
        case GitHubReleaseFetcher.FetchError.badURL: return "bad URL"
        case UpdatePolicy.DecodeError.invalidResponse: return "unexpected response"
        default: return String(describing: type(of: error))
        }
    }

    /// Whether this copy was installed with Homebrew (it keeps a Caskroom entry).
    static var installedWithHomebrew: Bool {
        ["/opt/homebrew/Caskroom/zuntrio", "/usr/local/Caskroom/zuntrio"].contains {
            FileManager.default.fileExists(atPath: $0)
        }
    }

    static let releasesPage = URL(string: "https://github.com/Zuntrio/zuntrio/releases")
}

/// The dialogs after "Check for Updates…" (wording approved by the owner, 2026-11-20).
@MainActor
enum UpdatePrompt {
    static func show(_ outcome: UpdateChecker.Outcome) {
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        var link: URL?
        switch outcome {
        case .available(let update):
            alert.messageText = "Zuntrio \(update.version.displayName) is available."
            var text = "You have \(ReleaseInfo.displayVersion)."
            if UpdateChecker.installedWithHomebrew {
                text += "\n\nInstalled with Homebrew? Run: brew upgrade --cask zuntrio"
            }
            alert.informativeText = text
            alert.addButton(withTitle: "View Release")
            alert.addButton(withTitle: "Later")
            link = update.url
        case .upToDate:
            alert.messageText = "You're up to date."
            alert.informativeText = "Zuntrio \(ReleaseInfo.displayVersion) is the newest version."
            alert.addButton(withTitle: "OK")
        case .failed:
            alert.messageText = "Couldn't check for updates."
            alert.informativeText = "Check your internet connection and try again."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "View Releases")
        }
        NSApp.activate()
        let response = alert.runModal()
        switch (outcome, response) {
        case (.available, .alertFirstButtonReturn):
            if let link { NSWorkspace.shared.open(link) }
        case (.failed, .alertSecondButtonReturn):
            if let page = UpdateChecker.releasesPage { NSWorkspace.shared.open(page) }
        default:
            break
        }
    }
}
