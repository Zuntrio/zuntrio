import ZuntrioCore

/// The full release version, including the beta or RC stage that Info.plist can't
/// carry (CFBundleShortVersionString stays X.Y.Z). `scripts/release.sh prepare`
/// updates it, and `build` checks that it matches the tag.
enum ReleaseInfo {
    static let version = "1.0.0-rc.1"

    static var current: ReleaseVersion? { ReleaseVersion(version) }

    /// "0.1.0 beta 1", or the raw string if it doesn't parse.
    static var displayVersion: String { current?.displayName ?? version }
}
