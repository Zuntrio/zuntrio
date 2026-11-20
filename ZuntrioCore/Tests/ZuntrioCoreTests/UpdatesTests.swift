import Foundation
import Testing
@testable import ZuntrioCore

@Suite struct ReleaseVersionTests {
    @Test func parsesStableBetaAndRC() throws {
        let stable = try #require(ReleaseVersion("1.2.3"))
        #expect(stable == ReleaseVersion(major: 1, minor: 2, patch: 3))
        #expect(!stable.isPrerelease)

        let beta = try #require(ReleaseVersion("v0.1.0-beta.2"))
        #expect(beta == ReleaseVersion(major: 0, minor: 1, patch: 0, stage: .beta, stageNumber: 2))
        #expect(beta.isPrerelease)

        let rc = try #require(ReleaseVersion("1.0.0-rc.1"))
        #expect(rc.stage == .rc)
        #expect(rc.stageNumber == 1)
    }

    @Test(arguments: [
        "", "v", "1", "1.2", "1.2.3.4", "1.2.x", "-1.2.3", "1.2.3-", "1.2.3-beta", "1.2.3-beta.",
        "1.2.3-alpha.1", "1.2.3-beta.1.2", "1.2.3 ", " 1.2.3", "vv1.2.3", "1..3", "１.2.3", "1.2.3-beta.x",
    ])
    func rejectsMalformed(_ text: String) {
        #expect(ReleaseVersion(text) == nil)
    }

    @Test func ordering() throws {
        let ordered = ["0.1.0-beta.1", "0.1.0-beta.2", "0.1.0-beta.10", "0.1.0-rc.1", "0.1.0-rc.2", "0.1.0",
                       "0.1.1-beta.1", "0.1.1", "0.2.0", "0.10.0", "1.0.0-beta.1", "1.0.0-rc.1", "1.0.0", "1.0.1", "2.0.0"]
        let versions = try ordered.map { try #require(ReleaseVersion($0)) }
        for (lower, higher) in zip(versions, versions.dropFirst()) {
            #expect(lower < higher, "\(lower) should be older than \(higher)")
        }
        #expect(versions.shuffled().sorted() == versions)
    }

    @Test func descriptions() throws {
        #expect(try #require(ReleaseVersion("v0.1.0-beta.2")).description == "0.1.0-beta.2")
        #expect(try #require(ReleaseVersion("0.1.0-beta.2")).displayName == "0.1.0 beta 2")
        #expect(try #require(ReleaseVersion("1.0.0-rc.1")).displayName == "1.0.0 RC 1")
        #expect(try #require(ReleaseVersion("1.0.0")).displayName == "1.0.0")
    }

    @Test func stableIgnoresStageNumber() {
        #expect(ReleaseVersion(major: 1, minor: 0, patch: 0, stage: .stable, stageNumber: 5) == ReleaseVersion(major: 1, minor: 0, patch: 0))
    }
}

@Suite struct UpdatePolicyTests {
    func release(_ tag: String, prerelease: Bool? = nil, draft: Bool = false) -> PublishedRelease {
        let isPre = prerelease ?? tag.contains("-")
        let url = URL(string: "https://github.com/Zuntrio/zuntrio/releases/tag/\(tag)")!
        return PublishedRelease(tagName: tag, htmlURL: url, draft: draft, prerelease: isPre)
    }

    func version(_ text: String) throws -> ReleaseVersion { try #require(ReleaseVersion(text)) }

    @Test func betaBuildIsOfferedNewerBeta() throws {
        let update = UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.1"),
                                               in: [release("v0.1.0-beta.2"), release("v0.1.0-beta.1")])
        #expect(update?.version == (try version("0.1.0-beta.2")))
        #expect(update?.url.absoluteString == "https://github.com/Zuntrio/zuntrio/releases/tag/v0.1.0-beta.2")
    }

    @Test func betaBuildIsOfferedTheStableRelease() throws {
        let update = UpdatePolicy.newestUpdate(for: try version("1.0.0-rc.1"),
                                               in: [release("v1.0.0"), release("v1.0.0-rc.1"), release("v0.1.0-beta.2")])
        #expect(update?.version == (try version("1.0.0")))
    }

    @Test func stableBuildIgnoresPrereleases() throws {
        let releases = [release("v1.1.0-beta.1"), release("v1.0.0")]
        #expect(UpdatePolicy.newestUpdate(for: try version("1.0.0"), in: releases) == nil)
        let newer = UpdatePolicy.newestUpdate(for: try version("1.0.0"), in: [release("v1.1.0-beta.1"), release("v1.0.1"), release("v1.0.0")])
        #expect(newer?.version == (try version("1.0.1")))
    }

    @Test func upToDateOrNewerThanPublished() throws {
        #expect(UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.2"), in: [release("v0.1.0-beta.2"), release("v0.1.0-beta.1")]) == nil)
        #expect(UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.3"), in: [release("v0.1.0-beta.2")]) == nil)
        #expect(UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.1"), in: []) == nil)
    }

    @Test func ignoresDraftsAndUnparsableTags() throws {
        let releases = [release("v9.0.0", draft: true), release("nightly"), release("v0.2.0-alpha.1"), release("v0.1.0-beta.2")]
        let update = UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.1"), in: releases)
        #expect(update?.version == (try version("0.1.0-beta.2")))
    }

    @Test func usesTheTagNotThePrereleaseFlag() throws {
        // A stable-looking tag marked as a pre-release on GitHub still counts as stable by its tag.
        let update = UpdatePolicy.newestUpdate(for: try version("1.0.0"), in: [release("v1.0.1", prerelease: true)])
        #expect(update?.version == (try version("1.0.1")))
    }

    @Test func picksTheNewestRegardlessOfOrder() throws {
        let releases = [release("v0.1.0-beta.2"), release("v0.1.0-beta.4"), release("v0.1.0-beta.3")]
        #expect(UpdatePolicy.newestUpdate(for: try version("0.1.0-beta.1"), in: releases)?.version == (try version("0.1.0-beta.4")))
    }

    @Test func decodesGitHubResponse() throws {
        let json = """
        [{"url":"https://api.github.com/x","tag_name":"v0.1.0-beta.2","name":"Zuntrio 0.1.0 beta 2",
          "html_url":"https://github.com/Zuntrio/zuntrio/releases/tag/v0.1.0-beta.2","draft":false,"prerelease":true,
          "assets":[{"name":"Zuntrio.zip"}]}]
        """
        let releases = try UpdatePolicy.decodeReleases(Data(json.utf8))
        #expect(releases == [release("v0.1.0-beta.2")])
    }

    @Test(arguments: ["", "{}", "{\"message\":\"API rate limit exceeded\"}", "[{\"tag_name\":1}]", "<html>"])
    func rejectsUnexpectedResponses(_ body: String) {
        #expect(throws: UpdatePolicy.DecodeError.invalidResponse) {
            try UpdatePolicy.decodeReleases(Data(body.utf8))
        }
    }

    @Test func automaticCheckSchedule() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let day = UpdatePolicy.automaticInterval
        #expect(!UpdatePolicy.isAutomaticCheckDue(enabled: false, lastCheck: nil, now: now))
        #expect(UpdatePolicy.isAutomaticCheckDue(enabled: true, lastCheck: nil, now: now))
        #expect(!UpdatePolicy.isAutomaticCheckDue(enabled: true, lastCheck: now.addingTimeInterval(-day + 1), now: now))
        #expect(UpdatePolicy.isAutomaticCheckDue(enabled: true, lastCheck: now.addingTimeInterval(-day), now: now))
        #expect(UpdatePolicy.isAutomaticCheckDue(enabled: true, lastCheck: now.addingTimeInterval(3600), now: now))
        #expect(!UpdatePolicy.isAutomaticCheckDue(enabled: false, lastCheck: now.addingTimeInterval(-10 * day), now: now))
    }
}
