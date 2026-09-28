import Foundation

enum DistributionReleaseWorkflowTests {
    static func runAll() throws {
        try testWorkflowUsesSerializedLeastPrivilegeProtectedPublication()
        try testWorkflowInstallsPinnedSwiftLintBeforeSourceGates()
        try testHomebrewBootstrapValidationSupportsNoPreviousPackagesWithNounset()
        try testResumptionUsesReviewedCurrentHomebrewValidator()
        try testSourceFreshnessPluginFailsBeforePreparation()
        try testRetainedBundleRestoresReleaseCommitBeforeSourcePublication()
        try testDisposablePublicationOrdersAndResumesImmutableStages()
        try testSourcePublishedRetryAcceptsLaterBranchDescendant()
        try testTapPublishedRetryAcceptsLaterUnrelatedTapCommit()
        try testOlderCandidateCannotResumeAfterNewerReleaseTag()
        try testTamperedRetainedCandidateFailsBeforeSourcePublication()
        try testReformattedRetainedManifestFailsBeforeSourcePublication()
        try testTamperedReleaseNotesFailBeforeSourcePublication()
        try testTamperedRetainedSourceBundleFailsBeforeSourcePublication()
        try testReformattedProductionManifestFailsSameVersionRetry()
        try testInvalidProductionManifestLeavesNoRetainedCandidate()
        try testPublicationAuthenticationHelperCleansUpAfterSuccessAndFailure()
    }

    private static func testWorkflowUsesSerializedLeastPrivilegeProtectedPublication() throws {
        let root = try repositoryRoot()
        let workflow = try String(contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        let candidateStager = try String(
            contentsOf: root.appendingPathComponent("scripts/release/stage-release-candidate.mjs"), encoding: .utf8)

        for required in [
            "workflow_dispatch:", "bootstrap:", "resume_run_id:", "push:", "branches: [master]",
            "group: calrelay-public-beta-release", "cancel-in-progress: false", "permissions:", "actions: read",
            "contents: read", "environment: public-beta-release", "runs-on: xcode-27",
            "persist-credentials: false", "node-version: 24.21.0", "package-manager-cache: false",
            "CALRELAY_SIGNING_CERTIFICATE_SHA1", "secrets.CALRELAY_SIGNING_CERTIFICATE_SHA1",
            "permission-contents: write", "CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY",
            "CALRELAY_RELEASE_GITHUB_APP_ID", "ondrej-winter/homebrew-tap", "if: always()",
            "compression-level: 0", "if-no-files-found: error", "retention-days: 30",
            "resume_run_id must be a positive workflow run ID", "bootstrap and resume_run_id are mutually exclusive",
            "actions/runs/${RESUME_RUN_ID}", "resume candidate does not match its protected release workflow run",
            "run.path !== \".github/workflows/release.yml\"", "run.head_branch !== \"master\"",
            "run.head_sha !== state.sourceRevision", "refs/remotes/calrelay-candidate/master", "git checkout --detach",
            "retained source bundle digest conflicts with release state",
            "Release workflow is restricted to ondrej-winter/calrelay",
            "CALRELAY_TAP_REPOSITORY must be ondrej-winter/homebrew-tap", "command -v gh", "command -v brew",
            "The previous tap must contain both CalRelay packages or neither", "release-publication.askpass-*",
            "--previous-packages-directory .build/previous-packages", ".build/previous-packages/Formula",
        ] {
            try expect(workflow.contains(required), "Release workflow must contain \(required)")
        }
        try expect(
            workflow.contains("if: needs.analyze.outputs.release == 'true'"),
            "Protected release work must be skipped for non-qualifying pushes")
        try expect(
            !workflow.contains("pull_request_target") && !workflow.contains("permissions: write-all"),
            "Release workflow must not expose privileged execution to untrusted triggers")
        try expect(
            !workflow.contains("CALRELAY_SIGNING_IDENTITY"),
            "Release workflow must not select the signing certificate by its display name")
        try expect(
            !workflow.contains("vars.CALRELAY_SIGNING_CERTIFICATE_SHA1"),
            "Release workflow must read the protected signing fingerprint from the secrets context")
        try expect(
            !workflow.contains("runs-on: [self-hosted"),
            "Release workflow must use the ephemeral GitHub-hosted Apple Silicon runner")
        try expect(
            !workflow.contains("archive: false"),
            "The retained multi-file candidate must use upload-artifact's archive container")
        try expect(
            candidateStager.contains("Candidate staging requires a clean tracked release worktree"),
            "Candidate staging must reject tracked worktree drift before retaining release provenance")
        let actionReferences = workflow.matches(of: /uses:\s+[^\s@]+@([^\s#]+)/).map { String($0.1) }
        try expect(!actionReferences.isEmpty, "Release workflow must declare its external actions")
        try expect(
            actionReferences.allSatisfy { $0.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil },
            "Every external action must be pinned to an immutable commit")

        guard let analyzeRange = workflow.range(of: "  analyze:"), let releaseRange = workflow.range(of: "  release:") else {
            throw TestFailure("Release workflow must define analyze and release jobs")
        }
        let analyzeJob = String(workflow[analyzeRange.lowerBound..<releaseRange.lowerBound])
        for protectedName in [
            "CALRELAY_DEVELOPER_ID_P12", "CALRELAY_NOTARY_API_KEY_P8",
            "CALRELAY_SIGNING_CERTIFICATE_SHA1", "CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY",
            "create-github-app-token",
        ] {
            try expect(!analyzeJob.contains(protectedName), "Analysis must not access protected value \(protectedName)")
        }
    }

    private static func testWorkflowInstallsPinnedSwiftLintBeforeSourceGates() throws {
        let root = try repositoryRoot()
        let workflow = try String(contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        let toolchainData = try Data(contentsOf: root.appendingPathComponent("scripts/release/toolchain.json"))
        guard
            let toolchain = try JSONSerialization.jsonObject(with: toolchainData) as? [String: Any],
            let swiftLint = toolchain["swiftLint"] as? [String: String]
        else {
            throw TestFailure("Release toolchain must declare pinned SwiftLint metadata")
        }

        try expect(
            swiftLint == [
                "version": "0.65.1",
                "asset": "portable_swiftlint.zip",
                "sha256": "c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0",
            ],
            "Release SwiftLint must use the reviewed official portable artifact and SHA-256")
        for required in [
            "Set up pinned SwiftLint", "toolchain.swiftLint", "swiftLint.asset !== \"portable_swiftlint.zip\"",
            "https://github.com/realm/SwiftLint/releases/download/${swiftlint_version}/${swiftlint_asset}",
            "shasum -a 256 -c -", "observed_version", "printf 'SWIFTLINT=%s\\n'",
        ] {
            try expect(workflow.contains(required), "Release workflow must contain \(required)")
        }
        try expect(!workflow.contains("brew install swiftlint"), "Release workflow must not resolve SwiftLint through Homebrew")

        guard
            let checkout = workflow.range(of: "- name: Check out release source"),
            let setup = workflow.range(of: "- name: Set up pinned SwiftLint"),
            let qualityGates = workflow.range(of: "- name: Run source quality gates")
        else {
            throw TestFailure("Release workflow must declare checkout, SwiftLint setup, and source quality gates")
        }
        try expect(checkout.lowerBound < setup.lowerBound, "SwiftLint setup must read metadata from the checked-out release source")
        try expect(setup.lowerBound < qualityGates.lowerBound, "SwiftLint must be available before source quality gates run")
    }

    private static func testHomebrewBootstrapValidationSupportsNoPreviousPackagesWithNounset() throws {
        let root = try repositoryRoot()
        let workflow = try String(
            contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        guard
            let step = workflow.range(of: "      - name: Validate Homebrew lifecycle without Calendar access\n"),
            let nextStep = workflow.range(
                of: "      - name: Publish formula and cask atomically\n",
                range: step.upperBound..<workflow.endIndex),
            let run = workflow.range(of: "        run: |\n", range: step.upperBound..<nextStep.lowerBound)
        else {
            throw TestFailure("Release workflow must define the Homebrew lifecycle validation step")
        }
        let script = workflow[run.upperBound..<nextStep.lowerBound]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.hasPrefix("          ") ? String(line.dropFirst(10)) : String(line) }
            .joined(separator: "\n")

        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(
            "calrelay-homebrew-workflow-\(UUID().uuidString)")
        let tools = fixture.appendingPathComponent("tools")
        let validator = fixture.appendingPathComponent("scripts/release/validate-homebrew-packages.mjs")
        defer { try? FileManager.default.removeItem(at: fixture) }
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: validator.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("// fake validator\n".utf8).write(to: validator)
        for tool in ["brew", "node"] {
            let executable = tools.appendingPathComponent(tool)
            try Data("#!/bin/sh\nprintf '%s\\n' \"$@\"\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(tools.path):\(environment["PATH"] ?? "")"

        let result = try command("/bin/bash", ["-c", script], at: fixture, environment: environment)

        try expect(
            result.status == 0,
            "Bootstrap Homebrew validation must support no previous packages under nounset: \(result.output)")
        try expect(
            !result.output.contains("--previous-packages-directory"),
            "Bootstrap Homebrew validation must omit previous-package arguments")
    }

    private static func testResumptionUsesReviewedCurrentHomebrewValidator() throws {
        let root = try repositoryRoot()
        let workflow = try String(
            contentsOf: root.appendingPathComponent(".github/workflows/release.yml"), encoding: .utf8)
        for required in [
            "Stage reviewed Homebrew validator for resumption",
            "git show \"${GITHUB_SHA}:scripts/release/validate-homebrew-packages.mjs\"",
            "${RUNNER_TEMP}/calrelay-validate-homebrew-packages.mjs",
            "RESUME: ${{ needs.analyze.outputs.resume }}",
            "node \"$validator\" \"${arguments[@]}\"",
        ] {
            try expect(workflow.contains(required), "Resumption workflow must contain \(required)")
        }
        guard
            let checkout = workflow.range(of: "- name: Check out release source"),
            let validator = workflow.range(of: "- name: Stage reviewed Homebrew validator for resumption"),
            let restore = workflow.range(of: "- name: Restore retained release commit from source bundle"),
            let homebrew = workflow.range(of: "- name: Validate Homebrew lifecycle without Calendar access")
        else {
            throw TestFailure("Release workflow must stage and use the reviewed Homebrew validator during resumption")
        }
        try expect(checkout.lowerBound < validator.lowerBound, "Validator staging requires the current workflow checkout")
        try expect(validator.lowerBound < restore.lowerBound, "Validator staging must precede immutable release checkout")
        try expect(restore.lowerBound < homebrew.lowerBound, "Homebrew validation must run after release source restoration")
    }

    private static func testSourceFreshnessPluginFailsBeforePreparation() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }

        let matching = try fixture.runFreshnessPlugin()
        try expect(matching.status == 0, "Matching remote master must pass source freshness: \(matching.output)")

        try fixture.advanceRemoteBranchTip()
        let stale = try fixture.runFreshnessPlugin()
        try expect(stale.status != 0, "Advanced remote master must fail before release preparation")
        try expect(stale.output.contains("remote master"), "Freshness failure must identify remote master advancement")
        try expect(
            try fixture.sourceSubject() == "fix: prepare release fixture",
            "Freshness verification must not create the release commit")
    }

    private static func testDisposablePublicationOrdersAndResumesImmutableStages() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try expect(try fixture.stateStage() == "artifacts-staged", "The immutable candidate must be retained before source publication")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Candidate staging must not mutate the source repository")

        let assets = try fixture.publish("assets")
        try expect(assets.status == 0, "Release assets must publish in the disposable repository: \(assets.output)")
        try expect(try fixture.stateStage() == "assets-verified", "Asset publication must stop after redownload verification")
        try expect(try fixture.remoteSourceIsPublishedRelease(), "Asset publication must first publish the exact release commit and tag")

        let tap = try fixture.publish("tap")
        try expect(tap.status == 0, "Tap publication must succeed after asset verification: \(tap.output)")
        try expect(try fixture.stateStage() == "complete", "Atomic tap publication must complete the release")
        try expect(
            try fixture.operationLog() == [
                "source-published", "release-created", "assets-published", "assets-verified", "tap-published", "complete",
            ],
            "Publication stages must occur in the accepted order")
        try expect(try fixture.tapContainsBothPackages(), "The tap commit must publish formula and cask together")
        let tapCommitCount = try fixture.tapCommitCount()

        try expect(try fixture.publish("assets").status == 0, "Matching asset publication retries must be idempotent")
        try expect(try fixture.publish("tap").status == 0, "Matching tap publication retries must be idempotent")
        try expect(try fixture.tapCommitCount() == tapCommitCount, "A matching retry must not create another tap commit")

        try fixture.corruptPublishedCLI()
        let mismatch = try fixture.publish("assets")
        try expect(mismatch.status != 0, "A changed same-version release asset must fail closed")
        try expect(mismatch.output.contains("SHA-256"), "Asset mismatch diagnostics must identify checksum verification")
    }

    private static func testRetainedBundleRestoresReleaseCommitBeforeSourcePublication() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()

        let restoredVersion = try fixture.restoreReleaseCommitFromCandidate()

        try expect(restoredVersion == "1.0.1", "The retained bundle must restore the prepared release commit")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Restoring the retained release commit must not require source publication")
    }

    private static func testTamperedRetainedCandidateFailsBeforeSourcePublication() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.corruptCandidateFormula()

        let result = try fixture.publish("assets")

        try expect(result.status != 0, "Tampered retained package content must fail closed")
        try expect(result.output.contains("conflicts"), "Tampered package diagnostics must explain the immutable conflict")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Candidate verification must fail before source publication")
    }

    private static func testOlderCandidateCannotResumeAfterNewerReleaseTag() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.publish("assets").requireSuccess()
        try fixture.publishLaterReleaseTag()

        let result = try fixture.publish("assets")

        try expect(result.status != 0, "An older retained candidate must not resume after a newer release tag")
        try expect(result.output.contains("newer release tag"), "Stale-candidate diagnostics must identify the newer release")
    }

    private static func testTapPublishedRetryAcceptsLaterUnrelatedTapCommit() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.publish("assets").requireSuccess()
        try fixture.publish("tap").requireSuccess()
        try fixture.advanceRemoteTapBranchTip()

        let retry = try fixture.publish("tap")

        try expect(retry.status == 0, "A later unrelated tap commit must not block same-version resumption: \(retry.output)")
        try expect(try fixture.tapContainsBothPackages(), "Tap descendant recovery must retain both exact packages")
    }

    private static func testSourcePublishedRetryAcceptsLaterBranchDescendant() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.publish("assets").requireSuccess()
        try fixture.advanceRemoteBranchTip()

        let retry = try fixture.publish("assets")

        try expect(retry.status == 0, "A later remote master descendant must not block same-version resumption: \(retry.output)")
        try expect(try fixture.stateStage() == "assets-verified", "The resumed release must retain its verified stage")
    }

    private static func testTamperedRetainedSourceBundleFailsBeforeSourcePublication() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.corruptCandidateSourceBundle()

        let result = try fixture.publish("assets")

        try expect(result.status != 0, "Tampered retained source bytes must fail closed")
        try expect(result.output.contains("source bundle"), "Source tampering diagnostics must identify the retained bundle")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Source bundle verification must fail before source publication")
    }

    private static func testReformattedRetainedManifestFailsBeforeSourcePublication() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.reformatRetainedManifest()

        let result = try fixture.publish("assets")

        try expect(result.status != 0, "Reformatted retained manifest bytes must fail closed")
        try expect(result.output.contains("manifest"), "Retained manifest diagnostics must identify immutable metadata")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Retained manifest verification must fail before source publication")
    }

    private static func testTamperedReleaseNotesFailBeforeSourcePublication() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.corruptReleaseNotes()

        let result = try fixture.publish("assets")

        try expect(result.status != 0, "Tampered release notes must fail closed")
        try expect(result.output.contains("release notes"), "Release-notes diagnostics must identify immutable metadata")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Release-notes verification must fail before source publication")
    }

    private static func testReformattedProductionManifestFailsSameVersionRetry() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.stageCandidate()
        try fixture.reformatProductionManifest()

        let result = try fixture.retryCandidateStaging()

        try expect(result.status != 0, "A same-version retry must preserve the production manifest bytes")
        try expect(result.output.contains("candidate manifest"), "Manifest retry failure must identify immutable candidate metadata")
        try expect(
            try fixture.remoteSourceIsCapturedRevisionWithoutReleaseTag(),
            "Manifest retry validation must not publish source state")
    }

    private static func testInvalidProductionManifestLeavesNoRetainedCandidate() throws {
        let fixture = try ReleaseWorkflowFixture()
        defer { fixture.remove() }
        try fixture.prepareArtifacts()
        try fixture.invalidateProductionManifest()

        let result = try fixture.retryCandidateStaging()

        try expect(result.status != 0, "Invalid production metadata must fail before candidate retention")
        try expect(!fixture.candidateExists(), "Invalid production metadata must not leave immutable release state")
    }

    private static func testPublicationAuthenticationHelperCleansUpAfterSuccessAndFailure() throws {
        let token = "AUTHENTICATION-HELPER-TOKEN-SENTINEL"
        let success = try ReleaseWorkflowFixture()
        defer { success.remove() }
        try success.stageCandidate()

        let successResult = try success.publish("assets", gitToken: token)

        try expect(successResult.status == 0, "Authenticated publication fixture must succeed: \(successResult.output)")
        try expect(try success.authenticationHelperPaths().isEmpty, "Successful publication must remove its askpass helper")
        try expect(!successResult.output.contains(token), "Successful publication must not disclose the Git token")

        let failure = try ReleaseWorkflowFixture()
        defer { failure.remove() }
        try failure.stageCandidate()
        try failure.advanceRemoteBranchTip()

        let failureResult = try failure.publish("assets", gitToken: token)

        try expect(failureResult.status != 0, "Stale source must fail after authentication helper setup")
        try expect(try failure.authenticationHelperPaths().isEmpty, "Failed publication must remove its askpass helper")
        try expect(!failureResult.output.contains(token), "Failed publication must not disclose the Git token")
    }

    static func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        throw TestFailure("Unable to resolve repository root")
    }

    private static func command(
        _ executable: String, _ arguments: [String], at directory: URL, environment: [String: String]? = nil
    ) throws -> ReleaseWorkflowProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ReleaseWorkflowProcessResult(status: process.terminationStatus, output: output)
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message) }
    }
}

private final class ReleaseWorkflowFixture {
    let sourceRoot: URL
    let root: URL
    let source: URL
    let sourceRemote: URL
    let tapRemote: URL
    let candidate: URL
    private let publisherLog: URL
    private let fakeRelease: URL
    private let fakeGH: URL
    private var sourceRevision = ""

    init() throws {
        sourceRoot = try DistributionReleaseWorkflowTests.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("calrelay-release-workflow-\(UUID().uuidString)")
        source = root.appendingPathComponent("source")
        sourceRemote = root.appendingPathComponent("source.git")
        tapRemote = root.appendingPathComponent("tap.git")
        candidate = root.appendingPathComponent("candidate")
        publisherLog = root.appendingPathComponent("publication.log")
        fakeRelease = root.appendingPathComponent("release")
        fakeGH = root.appendingPathComponent("gh")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try initializeBareRepository(sourceRemote)
        try command("/usr/bin/git", ["init", "-b", "master", source.path], at: root).requireSuccess()
        try git(source, ["config", "user.name", "CalRelay Tests"])
        try git(source, ["config", "user.email", "tests@example.invalid"])
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Sources/CalRelayCLI"), withIntermediateDirectories: true)
        try Data("1.0.0".utf8).write(to: source.appendingPathComponent("VERSION"))
        try Data("enum GeneratedReleaseVersion {\n    static let value = \"1.0.0\"\n}\n".utf8).write(
            to: source.appendingPathComponent("Sources/CalRelayCLI/GeneratedReleaseVersion.swift"))
        try Data("source\n".utf8).write(to: source.appendingPathComponent("fixture.txt"))
        try git(source, ["add", "."])
        try git(source, ["commit", "-m", "fix: prepare release fixture"])
        sourceRevision = try gitOutput(source, ["rev-parse", "HEAD"])
        try git(source, ["remote", "add", "origin", sourceRemote.path])
        try git(source, ["push", "-u", "origin", "master"])

        try Data("1.0.1".utf8).write(to: source.appendingPathComponent("VERSION"))
        try Data("enum GeneratedReleaseVersion {\n    static let value = \"1.0.1\"\n}\n".utf8).write(
            to: source.appendingPathComponent("Sources/CalRelayCLI/GeneratedReleaseVersion.swift"))
        try git(source, ["add", "VERSION", "Sources/CalRelayCLI/GeneratedReleaseVersion.swift"])
        try git(source, ["commit", "-m", "chore(release): v1.0.1"])
        try git(source, ["tag", "v1.0.1"])

        let tap = root.appendingPathComponent("tap")
        try initializeBareRepository(tapRemote)
        try command("/usr/bin/git", ["init", "-b", "master", tap.path], at: root).requireSuccess()
        try git(tap, ["config", "user.name", "CalRelay Tests"])
        try git(tap, ["config", "user.email", "tests@example.invalid"])
        try Data("tap\n".utf8).write(to: tap.appendingPathComponent("README.md"))
        try FileManager.default.createDirectory(at: tap.appendingPathComponent("Formula"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tap.appendingPathComponent("Casks"), withIntermediateDirectories: true)
        try Data("class Calrelay < Formula\n  version \"1.0.0\"\nend\n".utf8).write(
            to: tap.appendingPathComponent("Formula/calrelay.rb"))
        try Data("cask \"calrelay\" do\n  version \"1.0.0\"\nend\n".utf8).write(
            to: tap.appendingPathComponent("Casks/calrelay.rb"))
        try git(tap, ["add", "README.md", "Formula/calrelay.rb", "Casks/calrelay.rb"])
        try git(tap, ["commit", "-m", "chore: initialize tap"])
        try git(tap, ["remote", "add", "origin", tapRemote.path])
        try git(tap, ["push", "-u", "origin", "master"])
        try writeFakeGH()
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private func initializeBareRepository(_ repository: URL) throws {
        try command("/usr/bin/git", ["init", "--bare", "-b", "master", repository.path], at: root).requireSuccess()
        let head = try command(
            "/usr/bin/git", ["--git-dir", repository.path, "symbolic-ref", "HEAD"], at: root
        ).requiringOutput().trimmingCharacters(in: .whitespacesAndNewlines)
        guard head == "refs/heads/master" else {
            throw TestFailure("Bare release fixture repository must use master as its default branch")
        }
    }

    func runFreshnessPlugin() throws -> ReleaseWorkflowProcessResult {
        let plugin = sourceRoot.appendingPathComponent("scripts/release/verify-release-source.mjs").absoluteString
        let script = """
        const { verifyRelease } = await import(process.argv[1]);
        await verifyRelease({}, {
          cwd: process.argv[2],
          env: { CALRELAY_RELEASE_SOURCE_REVISION: process.argv[3] },
          options: { repositoryUrl: process.argv[4] },
        });
        """
        return try command(
            "/usr/bin/env",
            ["node", "--input-type=module", "--eval", script, plugin, source.path, sourceRevision, sourceRemote.path],
            at: source)
    }

    func advanceRemoteBranchTip() throws {
        let clone = root.appendingPathComponent("advance")
        try command("/usr/bin/git", ["clone", sourceRemote.path, clone.path], at: root).requireSuccess()
        try git(clone, ["config", "user.name", "CalRelay Tests"])
        try git(clone, ["config", "user.email", "tests@example.invalid"])
        try Data("advanced\n".utf8).write(to: clone.appendingPathComponent("advanced.txt"))
        try git(clone, ["add", "advanced.txt"])
        try git(clone, ["commit", "-m", "docs: advance remote"])
        try git(clone, ["push", "origin", "master"])
    }

    func publishLaterReleaseTag() throws {
        let clone = root.appendingPathComponent("later-release")
        try command("/usr/bin/git", ["clone", sourceRemote.path, clone.path], at: root).requireSuccess()
        try git(clone, ["config", "user.name", "CalRelay Tests"])
        try git(clone, ["config", "user.email", "tests@example.invalid"])
        try Data("1.0.2".utf8).write(to: clone.appendingPathComponent("VERSION"))
        try Data("enum GeneratedReleaseVersion {\n    static let value = \"1.0.2\"\n}\n".utf8).write(
            to: clone.appendingPathComponent("Sources/CalRelayCLI/GeneratedReleaseVersion.swift"))
        try git(clone, ["add", "VERSION", "Sources/CalRelayCLI/GeneratedReleaseVersion.swift"])
        try git(clone, ["commit", "-m", "chore(release): v1.0.2"])
        try git(clone, ["tag", "v1.0.2"])
        try git(clone, ["push", "origin", "master", "refs/tags/v1.0.2"])
    }

    func advanceRemoteTapBranchTip() throws {
        let clone = root.appendingPathComponent("advance-tap")
        try command("/usr/bin/git", ["clone", tapRemote.path, clone.path], at: root).requireSuccess()
        try git(clone, ["config", "user.name", "CalRelay Tests"])
        try git(clone, ["config", "user.email", "tests@example.invalid"])
        try Data("unrelated tap update\n".utf8).write(to: clone.appendingPathComponent("unrelated.txt"))
        try git(clone, ["add", "unrelated.txt"])
        try git(clone, ["commit", "-m", "docs: update tap metadata"])
        try git(clone, ["push", "origin", "master"])
    }

    func sourceSubject() throws -> String { try gitOutput(source, ["log", "-2", "--format=%s"]).split(separator: "\n").last.map(String.init) ?? "" }

    func stageCandidate() throws {
        try prepareArtifacts()
        try retryCandidateStaging().requireSuccess()
    }

    func prepareArtifacts() throws {
        let artifacts = root.appendingPathComponent("artifacts")
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
        let cli = artifacts.appendingPathComponent("calrelay-1.0.1-arm64.tar.gz")
        let app = artifacts.appendingPathComponent("CalRelay-1.0.1-arm64.zip")
        try Data("immutable-cli".utf8).write(to: cli)
        try Data("immutable-app".utf8).write(to: app)
        let manifest = artifacts.appendingPathComponent("candidate-manifest.json")
        let value: [String: Any] = [
            "schemaVersion": 1,
            "version": "1.0.1",
            "architecture": "arm64",
            "minimumMacOS": "26.0",
            "sdk": "27.0",
            "cli": ["name": cli.lastPathComponent, "sha256": try sha256(cli)],
            "app": ["name": app.lastPathComponent, "sha256": try sha256(app)],
        ]
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: manifest)
    }

    func retryCandidateStaging() throws -> ReleaseWorkflowProcessResult {
        let artifacts = root.appendingPathComponent("artifacts")
        let manifest = artifacts.appendingPathComponent("candidate-manifest.json")
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ProcessInfo.processInfo.environment["PATH"]
        return try command(
            "/usr/bin/env",
            [
                "node", sourceRoot.appendingPathComponent("scripts/release/stage-release-candidate.mjs").path,
                "--candidate-directory", candidate.path, "--artifacts-directory", artifacts.path,
                "--manifest", manifest.path,
                "--version", "1.0.1", "--previous-version", "1.0.0", "--source-revision", sourceRevision,
            ], at: source, environment: environment)
    }

    func publish(_ stage: String, gitToken: String? = nil) throws -> ReleaseWorkflowProcessResult {
        var environment = ProcessInfo.processInfo.environment
        environment["CALRELAY_RELEASE_OPERATION_LOG"] = publisherLog.path
        environment["CALRELAY_FAKE_RELEASE_DIRECTORY"] = fakeRelease.path
        environment["CALRELAY_GIT_TOKEN"] = gitToken
        return try command(
            "/usr/bin/env",
            [
                "node", sourceRoot.appendingPathComponent("scripts/release/publish-release.mjs").path, stage,
                "--candidate-directory", candidate.path, "--source-repository", "example/source",
                "--tap-repository", "example/tap", "--source-remote", sourceRemote.path,
                "--tap-remote", tapRemote.path, "--work-directory", root.appendingPathComponent("publish-work").path,
                "--gh", fakeGH.path,
            ], at: source, environment: environment)
    }

    func authenticationHelperPaths() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("publish-work.askpass-") }
    }

    func restoreReleaseCommitFromCandidate() throws -> String {
        let checkout = root.appendingPathComponent("resume-checkout")
        try command("/usr/bin/git", ["clone", sourceRemote.path, checkout.path], at: root).requireSuccess()
        let state = try JSONSerialization.jsonObject(
            with: Data(contentsOf: candidate.appendingPathComponent("release-state.json")))
        guard
            let value = state as? [String: Any],
            let releaseCommit = value["releaseCommit"] as? String,
            let tag = value["tag"] as? String
        else {
            throw TestFailure("Unable to decode retained release source metadata")
        }
        let bundle = candidate.appendingPathComponent("source.bundle")
        try git(checkout, ["bundle", "verify", bundle.path])
        try git(checkout, [
            "fetch", "--no-tags", bundle.path, "refs/heads/master:refs/remotes/calrelay-candidate/master",
        ])
        try git(checkout, ["fetch", "--no-tags", bundle.path, "refs/tags/\(tag):refs/tags/\(tag)"])
        guard try gitOutput(checkout, ["rev-parse", "refs/remotes/calrelay-candidate/master"]) == releaseCommit else {
            throw TestFailure("Restored candidate branch must identify the retained release commit")
        }
        guard try gitOutput(checkout, ["rev-parse", "refs/tags/\(tag)"]) == releaseCommit else {
            throw TestFailure("Restored candidate tag must identify the retained release commit")
        }
        try git(checkout, ["checkout", "--detach", releaseCommit])
        return try String(contentsOf: checkout.appendingPathComponent("VERSION"), encoding: .utf8)
    }

    func stateStage() throws -> String {
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: candidate.appendingPathComponent("release-state.json")))
        guard let state = value as? [String: Any], let stage = state["stage"] as? String else {
            throw TestFailure("Unable to decode release stage")
        }
        return stage
    }

    func operationLog() throws -> [String] {
        try String(contentsOf: publisherLog, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func tapContainsBothPackages() throws -> Bool {
        let formula = try command(
            "/usr/bin/git", ["--git-dir", tapRemote.path, "show", "master:Formula/calrelay.rb"], at: root)
        let cask = try command(
            "/usr/bin/git", ["--git-dir", tapRemote.path, "show", "master:Casks/calrelay.rb"], at: root)
        return formula.status == 0 && cask.status == 0 && formula.output.contains("1.0.1") && cask.output.contains("1.0.1")
    }

    func remoteSourceIsCapturedRevisionWithoutReleaseTag() throws -> Bool {
        let branch = try command(
            "/usr/bin/git", ["--git-dir", sourceRemote.path, "rev-parse", "master"], at: root).requiringOutput()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = try command(
            "/usr/bin/git", ["--git-dir", sourceRemote.path, "show-ref", "--verify", "refs/tags/v1.0.1"], at: root)
        return branch == sourceRevision && tag.status != 0
    }

    func remoteSourceIsPublishedRelease() throws -> Bool {
        let releaseCommit = try gitOutput(source, ["rev-parse", "HEAD"])
        let branch = try command(
            "/usr/bin/git", ["--git-dir", sourceRemote.path, "rev-parse", "master"], at: root).requiringOutput()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = try command(
            "/usr/bin/git", ["--git-dir", sourceRemote.path, "rev-parse", "refs/tags/v1.0.1"], at: root).requiringOutput()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return branch == releaseCommit && tag == releaseCommit
    }

    func tapCommitCount() throws -> Int {
        let output = try command(
            "/usr/bin/git", ["--git-dir", tapRemote.path, "rev-list", "--count", "master"], at: root).requiringOutput()
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
    }

    func corruptPublishedCLI() throws {
        try Data("corrupt".utf8).write(to: fakeRelease.appendingPathComponent("calrelay-1.0.1-arm64.tar.gz"))
    }

    func corruptCandidateFormula() throws {
        let formula = candidate.appendingPathComponent("packages/Formula/calrelay.rb")
        let handle = try FileHandle(forWritingTo: formula)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n# tampered\n".utf8))
    }

    func corruptCandidateSourceBundle() throws {
        let bundle = candidate.appendingPathComponent("source.bundle")
        let handle = try FileHandle(forWritingTo: bundle)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("tampered".utf8))
    }

    func reformatProductionManifest() throws {
        let manifest = root.appendingPathComponent("artifacts/candidate-manifest.json")
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest))
        let reformatted = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
        try reformatted.write(to: manifest)
    }

    func invalidateProductionManifest() throws {
        let manifest = root.appendingPathComponent("artifacts/candidate-manifest.json")
        var value = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any] ?? [:]
        value["architecture"] = "x86_64"
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: manifest)
    }

    func candidateExists() -> Bool {
        FileManager.default.fileExists(atPath: candidate.path)
    }

    func reformatRetainedManifest() throws {
        let manifest = candidate.appendingPathComponent("candidate-manifest.json")
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest))
        let reformatted = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
        try reformatted.write(to: manifest)
    }

    func corruptReleaseNotes() throws {
        let notes = candidate.appendingPathComponent("release-notes.md")
        let handle = try FileHandle(forWritingTo: notes)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("tampered\n".utf8))
    }

    private func writeFakeGH() throws {
        let contents = """
        #!/bin/sh
        set -eu
        directory="$CALRELAY_FAKE_RELEASE_DIRECTORY"
        command="$1"
        subcommand="$2"
        shift 2
        if [ "$command" != release ]; then exit 64; fi
        case "$subcommand" in
          view)
            [ -f "$directory/published" ] || exit 1
            printf '{"tagName":"v1.0.1","isDraft":false,"isImmutable":true,"assets":[{"name":"CalRelay-1.0.1-arm64.zip"},{"name":"SHA256SUMS"},{"name":"calrelay-1.0.1-arm64.tar.gz"}]}\\n'
            ;;
          create)
            mkdir -p "$directory"
            for argument in "$@"; do
              [ -f "$argument" ] && cp "$argument" "$directory/"
            done
            : > "$directory/published"
            ;;
          download)
            target=.
            while [ "$#" -gt 0 ]; do
              if [ "$1" = --dir ]; then shift; target="$1"; fi
              shift || true
            done
            mkdir -p "$target"
            cp "$directory/CalRelay-1.0.1-arm64.zip" "$target/"
            cp "$directory/SHA256SUMS" "$target/"
            cp "$directory/calrelay-1.0.1-arm64.tar.gz" "$target/"
            ;;
          *) exit 64 ;;
        esac
        """
        try Data(contents.utf8).write(to: fakeGH)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeGH.path)
    }

    @discardableResult
    private func git(_ repository: URL, _ arguments: [String]) throws -> ReleaseWorkflowProcessResult {
        let result = try command("/usr/bin/git", ["-C", repository.path] + arguments, at: repository)
        try result.requireSuccess()
        return result
    }

    private func gitOutput(_ repository: URL, _ arguments: [String]) throws -> String {
        try git(repository, arguments).output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sha256(_ url: URL) throws -> String {
        let output = try command("/usr/bin/shasum", ["-a", "256", url.path], at: root).requiringOutput()
        guard let digest = output.split(whereSeparator: { $0.isWhitespace }).first else {
            throw TestFailure("Unable to digest release workflow fixture")
        }
        return String(digest)
    }

    private func command(
        _ executable: String, _ arguments: [String], at directory: URL, environment: [String: String]? = nil
    ) throws -> ReleaseWorkflowProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        if let environment {
            process.environment = environment
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ReleaseWorkflowProcessResult(status: process.terminationStatus, output: output)
    }
}

private struct ReleaseWorkflowProcessResult {
    let status: Int32
    let output: String

    func requireSuccess() throws {
        guard status == 0 else { throw TestFailure("Command failed: \(output)") }
    }

    func requiringOutput() throws -> String {
        try requireSuccess()
        return output
    }
}