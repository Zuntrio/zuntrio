import Foundation

/// A Zuntrio release version: `X.Y.Z`, `X.Y.Z-beta.N` or `X.Y.Z-rc.N`, as used in the
/// GitHub tags (`v0.1.0-beta.1`). For the same X.Y.Z, betas come before release
/// candidates, which come before the stable release.
public struct ReleaseVersion: Sendable, Equatable, Hashable, Comparable, CustomStringConvertible {
    public enum Stage: Int, Sendable, Comparable {
        case beta = 0, rc = 1, stable = 2
        public static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let major: Int
    public let minor: Int
    public let patch: Int
    public let stage: Stage
    /// The N in beta.N or rc.N; 0 for stable releases.
    public let stageNumber: Int

    public init(major: Int, minor: Int, patch: Int, stage: Stage = .stable, stageNumber: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.stage = stage
        self.stageNumber = stage == .stable ? 0 : stageNumber
    }

    /// Parses `1.2.3`, `1.2.3-beta.4`, `1.2.3-rc.1`, with an optional leading `v`.
    /// Anything else returns nil.
    public init?(_ text: String) {
        var text = Substring(text)
        if text.first == "v" { text = text.dropFirst() }
        let parts = text.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              let major = Self.number(numbers[0]),
              let minor = Self.number(numbers[1]),
              let patch = Self.number(numbers[2]) else { return nil }
        guard parts.count == 2 else {
            self.init(major: major, minor: minor, patch: patch)
            return
        }
        let suffix = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard suffix.count == 2, let number = Self.number(suffix[1]) else { return nil }
        switch suffix[0] {
        case "beta": self.init(major: major, minor: minor, patch: patch, stage: .beta, stageNumber: number)
        case "rc": self.init(major: major, minor: minor, patch: patch, stage: .rc, stageNumber: number)
        default: return nil
        }
    }

    private static func number(_ text: Substring) -> Int? {
        guard !text.isEmpty, text.allSatisfy(\.isASCII), text.allSatisfy(\.isNumber) else { return nil }
        return Int(text)
    }

    public var isPrerelease: Bool { stage != .stable }

    /// The tag form without the leading `v`: `0.1.0-beta.2`.
    public var description: String {
        let base = "\(major).\(minor).\(patch)"
        switch stage {
        case .stable: return base
        case .beta: return "\(base)-beta.\(stageNumber)"
        case .rc: return "\(base)-rc.\(stageNumber)"
        }
    }

    /// For people: `0.1.0 beta 2`, `1.0.0 RC 1`, `1.0.0`.
    public var displayName: String {
        let base = "\(major).\(minor).\(patch)"
        switch stage {
        case .stable: return base
        case .beta: return "\(base) beta \(stageNumber)"
        case .rc: return "\(base) RC \(stageNumber)"
        }
    }

    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch, lhs.stage.rawValue, lhs.stageNumber)
            < (rhs.major, rhs.minor, rhs.patch, rhs.stage.rawValue, rhs.stageNumber)
    }
}

/// One entry from the GitHub Releases API (only the fields Zuntrio reads).
public struct PublishedRelease: Sendable, Equatable, Decodable {
    public let tagName: String
    public let htmlURL: URL
    public let draft: Bool
    public let prerelease: Bool

    public init(tagName: String, htmlURL: URL, draft: Bool = false, prerelease: Bool = false) {
        self.tagName = tagName
        self.htmlURL = htmlURL
        self.draft = draft
        self.prerelease = prerelease
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case draft, prerelease
    }
}

/// Decides whether a newer Zuntrio is available (ADR-0007). Pure: the app fetches
/// the release list and passes it in.
public enum UpdatePolicy {
    public struct Update: Sendable, Equatable {
        public let version: ReleaseVersion
        public let url: URL
    }

    public enum DecodeError: Error, Equatable {
        case invalidResponse
    }

    /// The GitHub Releases API response: a JSON array of releases.
    public static func decodeReleases(_ data: Data) throws -> [PublishedRelease] {
        do {
            return try JSONDecoder().decode([PublishedRelease].self, from: data)
        } catch {
            throw DecodeError.invalidResponse
        }
    }

    /// The newest release worth offering, or nil when `current` is up to date.
    /// A stable build is only offered stable releases; a beta or RC build is also
    /// offered newer pre-releases. Drafts and tags that don't parse are ignored.
    public static func newestUpdate(for current: ReleaseVersion, in releases: [PublishedRelease]) -> Update? {
        releases
            .filter { !$0.draft }
            .compactMap { release -> Update? in
                guard let version = ReleaseVersion(release.tagName) else { return nil }
                if version.isPrerelease && !current.isPrerelease { return nil }
                return Update(version: version, url: release.htmlURL)
            }
            .filter { $0.version > current }
            .max { $0.version < $1.version }
    }

    /// Automatic checks run at most once a day, and only when the user turned them on.
    public static let automaticInterval: TimeInterval = 24 * 60 * 60

    public static func isAutomaticCheckDue(enabled: Bool, lastCheck: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastCheck else { return true }
        // A clock set backwards shouldn't block checks for a long time.
        if lastCheck > now { return true }
        return now.timeIntervalSince(lastCheck) >= automaticInterval
    }
}
