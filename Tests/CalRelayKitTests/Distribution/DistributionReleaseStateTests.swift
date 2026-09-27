import Foundation

enum DistributionReleaseStateTests {
    static func runAll() throws {
        try testStagesArtifactsOnceAndResumesIncompleteRelease()
        try testPublicationStagesAcceptMatchingRetriesAndRejectMismatches()
        try testPublicationRejectsStaleSourceAndPartialPackageState()
        try testDefectiveAndCompromisedReleasesFailClosed()
    }

    private static func testStagesArtifactsOnceAndResumesIncompleteRelease() throws {
        let fixture = try ReleaseStateFixture(version: "1.0.1")
        defer { fixture.remove() }

        let created = try fixture.create()
        try expect(created.status == 0, "Release-state creation must succeed: \(created.output)")
        try fixture.requireSuccess(fixture.create())
        let state = try fixture.state()
        try expect(state.stage == "artifacts-staged", "New release state must begin after durable artifact staging")
        try expect(state.version == "1.0.1", "Release state must retain the selected version")
        try expect(state.previousKnownGoodVersion == "1.0.0", "The prior known-good release must remain recorded")
        try expect(
            try fixture.stagedData(named: state.artifacts.cli.name) == Data("cli-v1".utf8),
            "CLI bytes must be retained exactly")
        try expect(
            try fixture.stagedData(named: state.artifacts.app.name) == Data("app-v1".utf8),
            "App bytes must be retained exactly")

        try Data("rebuilt-cli".utf8).write(to: fixture.cliArtifact)
        let retry = try fixture.create()
        try expect(retry.status != 0, "A same-version retry must reject rebuilt artifact bytes")
        try expect(
            retry.output.contains("immutable"), "A rebuilt-artifact failure must explain the immutable-state conflict")
        try expect(
            try fixture.stagedData(named: state.artifacts.cli.name) == Data("cli-v1".utf8),
            "A retry must not replace staged bytes")

        let resumed = try fixture.resume()
        try expect(
            resumed.status == 0, "An incomplete release must be discoverable before new selection: \(resumed.output)")
        let summary = try JSONDecoder().decode(ResumeSummary.self, from: Data(resumed.output.utf8))
        try expect(summary.version == "1.0.1", "Resumption must retain the incomplete version")
    }

    private static func testPublicationStagesAcceptMatchingRetriesAndRejectMismatches() throws {
        let fixture = try ReleaseStateFixture(version: "1.2.3")
        defer { fixture.remove() }
        try fixture.requireSuccess(fixture.create())

        let source = try fixture.advanceSource()
        try fixture.requireSuccess(source)
        try fixture.requireSuccess(fixture.advanceSource())
        let wrongSource = try fixture.advanceSource(observedTagTarget: String(repeating: "b", count: 40))
        try expect(wrongSource.status != 0, "A matching retry must fail closed when immutable source state differs")

        let digests = try fixture.state().artifacts
        try fixture.requireSuccess(fixture.advanceAssets(cli: digests.cli.sha256, app: digests.app.sha256))
        try fixture.requireSuccess(fixture.advanceAssets(cli: digests.cli.sha256, app: digests.app.sha256))
        let wrongAssets = try fixture.advanceAssets(cli: String(repeating: "0", count: 64), app: digests.app.sha256)
        try expect(wrongAssets.status != 0, "A release asset mismatch must be rejected")

        try fixture.requireSuccess(fixture.advanceAssetsVerified(cli: digests.cli.sha256, app: digests.app.sha256))
        try fixture.requireSuccess(fixture.advanceAssetsVerified(cli: digests.cli.sha256, app: digests.app.sha256))
        try fixture.requireSuccess(fixture.advanceTap())
        try fixture.requireSuccess(fixture.advanceTap())
        try fixture.requireSuccess(fixture.advanceComplete())
        try fixture.requireSuccess(fixture.advanceComplete())
        try expect(
            try fixture.state().stage == "complete", "The release becomes complete only after the atomic tap stage")
    }

    private static func testPublicationRejectsStaleSourceAndPartialPackageState() throws {
        let stale = try ReleaseStateFixture(version: "1.3.0")
        defer { stale.remove() }
        try stale.requireSuccess(stale.create())
        let result = try stale.advanceSource(remoteBranchRevision: String(repeating: "f", count: 40))
        try expect(result.status != 0, "Remote master advancement must abort before source publication")
        try expect(
            result.output.contains("remote master"), "Stale-source failure must identify the source revision check")
        try expect(try stale.state().stage == "artifacts-staged", "Stale source must not advance publication state")

        let partial = try ReleaseStateFixture(version: "1.3.1")
        defer { partial.remove() }
        try partial.requireSuccess(partial.create())
        try partial.requireSuccess(partial.advanceSource())
        let digests = try partial.state().artifacts
        let missingApp = try partial.advanceAssets(cli: digests.cli.sha256, app: nil)
        try expect(missingApp.status != 0, "Asset publication must reject a partial CLI-only release")
        try partial.requireSuccess(partial.advanceAssets(cli: digests.cli.sha256, app: digests.app.sha256))
        try partial.requireSuccess(partial.advanceAssetsVerified(cli: digests.cli.sha256, app: digests.app.sha256))
        let missingCask = try partial.advanceTap(includeCask: false)
        try expect(missingCask.status != 0, "Tap publication must reject a formula-only update")
    }

    private static func testDefectiveAndCompromisedReleasesFailClosed() throws {
        let fixture = try ReleaseStateFixture(version: "1.4.0")
        defer { fixture.remove() }
        try fixture.requireSuccess(fixture.create())

        let disabled = try fixture.run(["disable", "--directory", fixture.releaseDirectory.path])
        try fixture.requireSuccess(disabled)
        let disabledState = try fixture.state()
        try expect(
            disabledState.securityDisposition == "disabled", "A compromised artifact must become non-installable state")
        try expect(disabledState.installable == false, "Disabled release state must not remain installable")

        let sameVersion = try fixture.run(["corrective", "--defective-version", "1.4.0", "--next-version", "1.4.0"])
        try expect(sameVersion.status != 0, "A defective release cannot be corrected in place")
        let minor = try fixture.run(["corrective", "--defective-version", "1.4.0", "--next-version", "1.5.0"])
        try expect(minor.status != 0, "Defective release recovery must be a higher patch, not a minor rewrite")
        let patch = try fixture.run(["corrective", "--defective-version", "1.4.0", "--next-version", "1.4.1"])
        try fixture.requireSuccess(patch)
        let policy = try JSONDecoder().decode(CorrectivePolicy.self, from: Data(patch.output.utf8))
        try expect(
            policy.calendarRollback == false, "Distribution recovery must never authorize automatic calendar rollback")
    }

    static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message) }
    }
}

private struct ReleaseArtifact: Decodable {
    let name: String
    let sha256: String
}

private struct ReleaseState: Decodable {
    struct Artifacts: Decodable {
        let cli: ReleaseArtifact
        let app: ReleaseArtifact
    }
    let version: String
    let previousKnownGoodVersion: String
    let stage: String
    let artifacts: Artifacts
    let securityDisposition: String
    let installable: Bool
}

private struct ResumeSummary: Decodable { let version: String }
private struct CorrectivePolicy: Decodable { let calendarRollback: Bool }
private struct ReleaseStateProcessResult {
    let status: Int32
    let output: String
}

private final class ReleaseStateFixture {
    let root: URL
    let releaseDirectory: URL
    let cliArtifact: URL
    let appArtifact: URL
    private let sourceRoot: URL
    private let sourceRevision = String(repeating: "a", count: 40)
    private let releaseCommit = String(repeating: "c", count: 40)
    private let formulaDigest = String(repeating: "d", count: 64)
    private let caskDigest = String(repeating: "e", count: 64)
    private let tapCommit = String(repeating: "f", count: 40)
    private let version: String

    init(version: String) throws {
        self.version = version
        sourceRoot = try Self.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DistributionReleaseStateTests-\(UUID().uuidString)")
        releaseDirectory = root.appendingPathComponent(version)
        cliArtifact = root.appendingPathComponent("calrelay-\(version)-arm64.tar.gz")
        appArtifact = root.appendingPathComponent("CalRelay-\(version)-arm64.zip")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("cli-v1".utf8).write(to: cliArtifact)
        try Data("app-v1".utf8).write(to: appArtifact)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func create() throws -> ReleaseStateProcessResult {
        try run([
            "create", "--directory", releaseDirectory.path, "--version", version, "--source-revision", sourceRevision,
            "--previous-version", "1.0.0", "--cli-artifact", cliArtifact.path, "--app-artifact", appArtifact.path
        ])
    }

    func resume() throws -> ReleaseStateProcessResult { try run(["resume", "--states-root", root.path]) }

    func advanceSource(remoteBranchRevision: String? = nil, observedTagTarget: String? = nil) throws
        -> ReleaseStateProcessResult
    {
        try run([
            "advance", "--directory", releaseDirectory.path, "--to", "source-published", "--remote-master",
            remoteBranchRevision ?? sourceRevision, "--release-commit", releaseCommit, "--observed-version", version,
            "--observed-release-commit", releaseCommit, "--observed-tag", "v\(version)", "--observed-tag-target",
            observedTagTarget ?? releaseCommit
        ])
    }

    func advanceAssets(cli: String?, app: String?) throws -> ReleaseStateProcessResult {
        var arguments = ["advance", "--directory", releaseDirectory.path, "--to", "assets-published"]
        if let cli { arguments += ["--observed-cli-sha256", cli] }
        if let app { arguments += ["--observed-app-sha256", app] }
        return try run(arguments)
    }

    func advanceAssetsVerified(cli: String, app: String) throws -> ReleaseStateProcessResult {
        try run([
            "advance", "--directory", releaseDirectory.path, "--to", "assets-verified", "--observed-cli-sha256", cli,
            "--observed-app-sha256", app
        ])
    }

    func advanceTap(includeCask: Bool = true) throws -> ReleaseStateProcessResult {
        var arguments = [
            "advance", "--directory", releaseDirectory.path, "--to", "tap-published", "--formula-sha256", formulaDigest,
            "--tap-commit", tapCommit, "--observed-formula-sha256", formulaDigest, "--observed-tap-commit", tapCommit
        ]
        if includeCask { arguments += ["--cask-sha256", caskDigest, "--observed-cask-sha256", caskDigest] }
        return try run(arguments)
    }

    func advanceComplete() throws -> ReleaseStateProcessResult {
        try run(["advance", "--directory", releaseDirectory.path, "--to", "complete"])
    }

    func state() throws -> ReleaseState {
        try JSONDecoder().decode(
            ReleaseState.self, from: Data(contentsOf: releaseDirectory.appendingPathComponent("release-state.json")))
    }

    func stagedData(named name: String) throws -> Data {
        try Data(contentsOf: releaseDirectory.appendingPathComponent("artifacts/\(name)"))
    }

    func requireSuccess(_ result: ReleaseStateProcessResult) throws {
        try DistributionReleaseStateTests.expect(result.status == 0, "Release-state command failed: \(result.output)")
    }

    func run(_ arguments: [String]) throws -> ReleaseStateProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments =
            ["node", sourceRoot.appendingPathComponent("scripts/release/release-state.mjs").path] + arguments
        process.currentDirectoryURL = sourceRoot
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ReleaseStateProcessResult(status: process.terminationStatus, output: output)
    }

    private static func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        throw TestFailure("Unable to resolve repository root")
    }
}
