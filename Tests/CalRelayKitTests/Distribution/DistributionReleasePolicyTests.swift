import Foundation

enum DistributionReleasePolicyTests {
    static func runAll() throws {
        try testQualifyingCommitMatrix()
        try testNonqualifyingAndBreakingOnlyCommitsPublishNothing()
        try testBootstrapIsExplicitAndOneTime()
        try testAutomaticPolicyStaysWithinOneX()
        try testPreparationCreatesOneExactReleaseCommitAndTag()
        try testSemanticReleasePluginsSupportExplicitBootstrap()
        try testPreparePluginCreatesReleaseCommitForSemanticRelease()
        try testPreparePluginRejectsVersionsOutsideOneX()
        try testReleaseNotesRemainAggregateAndPrivacySafe()
        try testSemanticReleaseRunnerConsumesBootstrapFlag()
        try testReleaseToolchainAndConfigurationArePinned()
    }

    private static func testQualifyingCommitMatrix() throws {
        for scenario in [
            ReleaseScenario(subject: "fix: repair scheduling", expectedType: "patch", expectedVersion: "1.0.1"),
            ReleaseScenario(subject: "fix!: replace scheduling internals", expectedType: "patch", expectedVersion: "1.0.1"),
            ReleaseScenario(subject: "feat: add distribution", expectedType: "minor", expectedVersion: "1.1.0"),
            ReleaseScenario(subject: "feat!: replace distribution", expectedType: "minor", expectedVersion: "1.1.0")
        ] {
            let fixture = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
            defer { fixture.remove() }
            try fixture.commit(subject: scenario.subject, body: "BREAKING CHANGE: compatibility warning")

            let selection = try fixture.select()

            try expect(selection.releaseType == scenario.expectedType, "Unexpected release type for \(scenario.subject)")
            try expect(selection.nextVersion == scenario.expectedVersion, "Unexpected next version for \(scenario.subject)")
            try expect(selection.breakingWarning, "Breaking-marked qualifying commits must retain a warning")
        }

        let mixed = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { mixed.remove() }
        try mixed.commit(subject: "fix: repair packaging")
        try mixed.commit(subject: "feat: add cask generation")
        let mixedSelection = try mixed.select()
        try expect(mixedSelection.releaseType == "minor", "Feature commits must take precedence over fixes")
        try expect(mixedSelection.nextVersion == "1.1.0", "Mixed fix and feature history must select the next minor")

        let mixedBreaking = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { mixedBreaking.remove() }
        try mixedBreaking.commit(subject: "chore!: replace internal release runner")
        try mixedBreaking.commit(subject: "fix: repair packaging")
        let mixedBreakingSelection = try mixedBreaking.select()
        try expect(mixedBreakingSelection.releaseType == "patch", "A breaking-only commit must not change the selected bump")
        try expect(mixedBreakingSelection.breakingWarning, "A breaking marker must contribute a warning to a selected release")
    }

    private static func testNonqualifyingAndBreakingOnlyCommitsPublishNothing() throws {
        for subject in [
            "docs: explain installation", "test: cover release policy", "refactor: simplify tooling",
            "chore!: replace internal runner", "chore(release): v1.0.1"
        ] {
            let fixture = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
            defer { fixture.remove() }
            try fixture.commit(subject: subject, body: "BREAKING CHANGE: internal-only warning")

            let selection = try fixture.select()

            try expect(selection.releaseType == nil, "Nonqualifying commit must not select a release: \(subject)")
            try expect(selection.nextVersion == nil, "Nonqualifying commit must not select a version: \(subject)")
        }
    }

    private static func testBootstrapIsExplicitAndOneTime() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: nil)
        defer { fixture.remove() }

        let ordinary = try fixture.select()
        try expect(ordinary.nextVersion == nil, "A no-tag history must not release without explicit bootstrap")

        let bootstrap = try fixture.select(bootstrap: true)
        try expect(bootstrap.releaseType == "major", "Bootstrap must use the explicit first-public-release transition")
        try expect(bootstrap.nextVersion == "1.0.0", "Bootstrap must select only 1.0.0")

        let notes = try fixture.runPolicy(arguments: ["notes", "--repository", fixture.root.path, "--bootstrap"])
        try expect(notes.status == 0, "Bootstrap release-note generation must succeed: \(notes.output)")
        try expect(notes.output.contains("initial public-beta release"), "Bootstrap notes must describe the initial release")

        let prepared = try fixture.runPolicy(arguments: ["prepare", "--repository", fixture.root.path, "--bootstrap"])
        try expect(prepared.status == 0, "Bootstrap preparation must succeed: \(prepared.output)")
        let bootstrapSubject = try fixture.git(["log", "-1", "--format=%s"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let bootstrapTagRevision = try fixture.git(["rev-list", "-n", "1", "v1.0.0"])
            .output.trimmingCharacters(in: .whitespacesAndNewlines)
        let bootstrapHeadRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        try expect(bootstrapSubject == "chore(release): v1.0.0", "Bootstrap must create the exact first release commit")
        try expect(bootstrapTagRevision == bootstrapHeadRevision, "The v1.0.0 tag must identify the bootstrap release commit")
        try expect(try fixture.read("VERSION") == "1.0.0", "Bootstrap preparation must update VERSION exactly")

        let published = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { published.remove() }
        let rejected = try published.runPolicy(arguments: ["select", "--repository", published.root.path, "--bootstrap"])
        try expect(rejected.status != 0, "Bootstrap must fail after a public release exists")
    }

    private static func testAutomaticPolicyStaysWithinOneX() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: "1.99.0")
        defer { fixture.remove() }
        try fixture.commit(subject: "feat!: continue public beta", body: "BREAKING CHANGE: beta migration")

        let selection = try fixture.select()

        try expect(selection.nextVersion == "1.100.0", "A 1.x feature must advance the minor component")
        try expect(selection.nextVersion != "2.0.0", "Automation must never infer 2.0.0")

        for unsupportedVersion in ["0.9.0", "2.0.0"] {
            let unsupported = try ReleaseRepositoryFixture(publicVersion: unsupportedVersion)
            defer { unsupported.remove() }
            try unsupported.commit(subject: "fix: reject unsupported release line")
            let rejected = try unsupported.runPolicy(arguments: ["select", "--repository", unsupported.root.path])
            try expect(rejected.status != 0, "Automatic release policy must reject \(unsupportedVersion)")
        }
    }

    private static func testPreparationCreatesOneExactReleaseCommitAndTag() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { fixture.remove() }
        try fixture.commit(subject: "fix: repair release packaging")
        let sourceRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try fixture.runPolicy(arguments: ["prepare", "--repository", fixture.root.path])
        try expect(result.status == 0, "Release preparation must succeed: \(result.output)")

        let subject = try fixture.git(["log", "-1", "--format=%s"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagRevision = try fixture.git(["rev-list", "-n", "1", "v1.0.1"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let headRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentRevision = try fixture.git(["rev-parse", "HEAD^"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let changedFiles = try fixture.git(["diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"])
            .output.split(separator: "\n").map(String.init).sorted()

        try expect(subject == "chore(release): v1.0.1", "Release preparation must create the exact release subject")
        try expect(tagRevision == headRevision, "The release tag must identify the release commit")
        try expect(parentRevision == sourceRevision, "Preparation must create exactly one commit after the source revision")
        try expect(
            changedFiles == ["Sources/CalRelayCLI/GeneratedReleaseVersion.swift", "VERSION"],
            "Release preparation must change only synchronized version artifacts")
        try expect(try fixture.read("VERSION") == "1.0.1", "Release preparation must update VERSION exactly")
    }

    private static func testPreparePluginRejectsVersionsOutsideOneX() throws {
        for unsupportedVersion in ["0.9.9", "2.0.0"] {
            let fixture = try ReleaseRepositoryFixture(publicVersion: nil)
            defer { fixture.remove() }
            let originalRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = try fixture.runPreparePlugin(version: unsupportedVersion)

            try expect(result.status != 0, "Prepare plugin must reject \(unsupportedVersion)")
            let finalRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
            try expect(finalRevision == originalRevision, "Rejected preparation must not create a commit")
            try expect(try fixture.read("VERSION") == "0.0.0", "Rejected preparation must not alter VERSION")
        }
    }

    private static func testSemanticReleasePluginsSupportExplicitBootstrap() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: nil)
        defer { fixture.remove() }

        let analysis = try fixture.runAnalyzePlugin(lastVersion: nil, bootstrap: true)
        try expect(analysis.status == 0, "Explicit semantic-release bootstrap analysis must succeed: \(analysis.output)")
        try expect(analysis.output.trimmingCharacters(in: .whitespacesAndNewlines) == "major", "Bootstrap analysis must select the first normal release")

        let notes = try fixture.runGenerateNotesPlugin(lastVersion: nil, nextVersion: "1.0.0", bootstrap: true)
        try expect(notes.status == 0, "Explicit semantic-release bootstrap notes must succeed: \(notes.output)")
        try expect(notes.output.contains("initial public-beta release"), "Bootstrap plugin notes must describe the initial release")

        let repeated = try fixture.runAnalyzePlugin(lastVersion: "1.0.0", bootstrap: true)
        try expect(repeated.status != 0, "Semantic-release bootstrap must fail after a public release exists")
    }

    private static func testPreparePluginCreatesReleaseCommitForSemanticRelease() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { fixture.remove() }
        try fixture.commit(subject: "fix: repair semantic-release preparation")
        let sourceRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = try fixture.runPreparePlugin(version: "1.0.1")

        try expect(result.status == 0, "Prepare plugin must succeed: \(result.output)")
        let subject = try fixture.git(["log", "-1", "--format=%s"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let headRevision = try fixture.git(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentRevision = try fixture.git(["rev-parse", "HEAD^"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        let changedFiles = try fixture.git(["diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"])
            .output.split(separator: "\n").map(String.init).sorted()
        let tags = try fixture.git(["tag", "--points-at", headRevision]).output.trimmingCharacters(in: .whitespacesAndNewlines)

        try expect(subject == "chore(release): v1.0.1", "Prepare plugin must create the exact release subject")
        try expect(parentRevision == sourceRevision, "Prepare plugin must create exactly one commit after the source revision")
        try expect(
            changedFiles == ["Sources/CalRelayCLI/GeneratedReleaseVersion.swift", "VERSION"],
            "Prepare plugin must change only synchronized version artifacts")
        try expect(tags.isEmpty, "Prepare plugin must leave tag creation to semantic-release")
        try expect(try fixture.read("VERSION") == "1.0.1", "Prepare plugin must update VERSION exactly")
    }

    private static func testReleaseNotesRemainAggregateAndPrivacySafe() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: "1.0.0")
        defer { fixture.remove() }
        let privateSentinel = "Sensitive Calendar Name"
        try fixture.commit(subject: "fix: \(privateSentinel)", body: "EventKit identifier sentinel")

        let result = try fixture.runPolicy(arguments: ["notes", "--repository", fixture.root.path])

        try expect(result.status == 0, "Release-note generation must succeed: \(result.output)")
        try expect(!result.output.contains(privateSentinel), "Release notes must not reproduce commit subjects")
        try expect(!result.output.contains("EventKit identifier sentinel"), "Release notes must not reproduce commit bodies")
        try expect(result.output.contains("patch public-beta release"), "Release notes must state the aggregate release type")
    }

    private static func testSemanticReleaseRunnerConsumesBootstrapFlag() throws {
        let fixture = try ReleaseRepositoryFixture(publicVersion: nil)
        defer { fixture.remove() }

        let bootstrap = try fixture.runSemanticReleaseRunner(arguments: ["--bootstrap", "--dry-run"])
        try expect(bootstrap.status == 0, "Bootstrap runner invocation must succeed: \(bootstrap.output)")
        try expect(bootstrap.output.contains("bootstrap=1"), "Bootstrap runner must expose the bootstrap environment")
        try expect(!bootstrap.output.contains("<--bootstrap>"), "Bootstrap runner must not forward its private flag")
        try expect(
            bootstrap.output.contains("<--package><semantic-release@25.0.9><semantic-release><--dry-run>"),
            "Bootstrap runner must invoke the pinned semantic-release version with remaining arguments")

        let ordinary = try fixture.runSemanticReleaseRunner(arguments: ["--dry-run"])
        try expect(ordinary.status == 0, "Ordinary runner invocation must succeed: \(ordinary.output)")
        try expect(ordinary.output.contains("bootstrap=unset"), "Ordinary runner must not leak bootstrap state")
    }

    private static func testReleaseToolchainAndConfigurationArePinned() throws {
        let root = try repositoryRoot()
        let configuration = try json(at: root.appendingPathComponent(".releaserc.json"))
        let toolchain = try json(at: root.appendingPathComponent("scripts/release/toolchain.json"))
        try expect(configuration["branches"] as? [String] == ["master"], "semantic-release must target only master")
        try expect(configuration["tagFormat"] as? String == "v${version}", "semantic-release must use vX.Y.Z tags")
        let plugins = configuration["plugins"] as? [String]
        try expect(
            plugins == [
                "./scripts/release/analyze-commits.mjs", "./scripts/release/verify-release-source.mjs",
                "./scripts/release/generate-notes.mjs",
                "./scripts/release/prepare-release.mjs"
            ],
            "semantic-release must use only the repository-owned policy plugins")
        try expect(toolchain["node"] as? String == "24.21.0", "Node must be pinned to the reviewed LTS patch")
        try expect(toolchain["semanticRelease"] as? String == "25.0.9", "semantic-release must be pinned exactly")
        try expect(
            toolchain["swiftLint"] as? [String: String] == [
                "version": "0.65.1",
                "asset": "portable_swiftlint.zip",
                "sha256": "c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0",
            ],
            "Release SwiftLint must be pinned to the reviewed official artifact and SHA-256")
        let pinnedPlugins = toolchain["plugins"] as? [String: String]
        try expect(
            pinnedPlugins == [
                "./scripts/release/analyze-commits.mjs": "1.2.0",
                "./scripts/release/verify-release-source.mjs": "1.0.0",
                "./scripts/release/generate-notes.mjs": "1.2.0",
                "./scripts/release/prepare-release.mjs": "1.2.0"
            ],
            "Every repository-owned semantic-release plugin must have an exact reviewed version")
        for (path, version) in pinnedPlugins ?? [:] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            try expect(
                source.contains("export const pluginVersion = \"\(version)\";"),
                "The pinned plugin revision must match the repository-owned plugin source")
        }
        try expect(
            try semanticReleaseConfigurationArtifacts(at: root) == [".releaserc.json"],
            ".releaserc.json must be the only semantic-release configuration artifact")
        try expect(try fixtureAbsent(at: root, paths: ["package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml"]),
                   "Release automation must not add a Node package manifest or lockfile")
    }

    private static func json(at url: URL) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let dictionary = object as? [String: Any] else { throw TestFailure("Expected JSON object at \(url.path)") }
        return dictionary
    }

    private static func fixtureAbsent(at root: URL, paths: [String]) throws -> Bool {
        paths.allSatisfy { !FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    private static func semanticReleaseConfigurationArtifacts(at root: URL) throws -> [String] {
        let candidates = [
            ".releaserc", ".releaserc.json", ".releaserc.yaml", ".releaserc.yml", ".releaserc.js",
            ".releaserc.cjs", "release.config.js", "release.config.cjs", "release.config.mjs"
        ]
        return candidates.filter { FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    private static func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        throw TestFailure("Unable to resolve the repository root from #filePath")
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message) }
    }
}

private struct ReleaseScenario {
    let subject: String
    let expectedType: String
    let expectedVersion: String
}

private struct ReleaseSelection: Decodable {
    let releaseType: String?
    let nextVersion: String?
    let breakingWarning: Bool
}

private final class ReleaseRepositoryFixture {
    let root: URL
    private let sourceRoot: URL

    init(publicVersion: String?) throws {
        sourceRoot = try Self.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DistributionReleasePolicyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try git(["init", "-b", "master"])
        try git(["config", "user.name", "CalRelay Tests"])
        try git(["config", "user.email", "tests@example.invalid"])
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources/CalRelayCLI"), withIntermediateDirectories: true)
        let initialVersion = publicVersion ?? "0.0.0"
        try writeVersion(initialVersion)
        try Data("fixture\n".utf8).write(to: root.appendingPathComponent("README.md"))
        try git(["add", "VERSION", "Sources/CalRelayCLI/GeneratedReleaseVersion.swift", "README.md"])
        try git(["commit", "-m", "chore: initialize fixture"])
        if let publicVersion { try git(["tag", "v\(publicVersion)"]) }
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func commit(subject: String, body: String? = nil) throws {
        let history = root.appendingPathComponent("history.txt")
        let existing = (try? String(contentsOf: history, encoding: .utf8)) ?? ""
        try Data((existing + UUID().uuidString + "\n").utf8).write(to: history)
        try git(["add", "history.txt"])
        var arguments = ["commit", "-m", subject]
        if let body { arguments += ["-m", body] }
        try git(arguments)
    }

    func select(bootstrap: Bool = false) throws -> ReleaseSelection {
        var arguments = ["select", "--repository", root.path]
        if bootstrap { arguments.append("--bootstrap") }
        let result = try runPolicy(arguments: arguments)
        guard result.status == 0 else { throw TestFailure("Release selection failed: \(result.output)") }
        return try JSONDecoder().decode(ReleaseSelection.self, from: Data(result.output.utf8))
    }

    func runPolicy(arguments: [String]) throws -> ReleaseProcessResult {
        try Self.run(
            executable: "/usr/bin/env",
            arguments: ["node", sourceRoot.appendingPathComponent("scripts/release/release-policy.mjs").path] + arguments,
            directory: sourceRoot)
    }

    func runPreparePlugin(version: String) throws -> ReleaseProcessResult {
        let plugin = sourceRoot.appendingPathComponent("scripts/release/prepare-release.mjs").absoluteString
        let script = """
        const { prepare } = await import(process.argv[1]);
        await prepare({}, {
          cwd: process.argv[2],
          nextRelease: { version: process.argv[3] },
          logger: { log() {} },
        });
        """
        return try Self.run(
            executable: "/usr/bin/env",
            arguments: ["node", "--input-type=module", "--eval", script, plugin, root.path, version],
            directory: sourceRoot)
    }

    func runAnalyzePlugin(lastVersion: String?, bootstrap: Bool) throws -> ReleaseProcessResult {
        let plugin = sourceRoot.appendingPathComponent("scripts/release/analyze-commits.mjs").absoluteString
        let script = """
        const { analyzeCommits } = await import(process.argv[1]);
        const result = await analyzeCommits({}, {
          commits: [],
          lastRelease: { version: process.argv[2] === "-" ? "" : process.argv[2] },
          env: { CALRELAY_RELEASE_BOOTSTRAP: process.argv[3] },
        });
        process.stdout.write(`${result}\n`);
        """
        return try Self.run(
            executable: "/usr/bin/env",
            arguments: [
                "node", "--input-type=module", "--eval", script, plugin, lastVersion ?? "-", bootstrap ? "1" : "0"
            ],
            directory: sourceRoot)
    }

    func runGenerateNotesPlugin(lastVersion: String?, nextVersion: String, bootstrap: Bool) throws -> ReleaseProcessResult {
        let plugin = sourceRoot.appendingPathComponent("scripts/release/generate-notes.mjs").absoluteString
        let script = """
        const { generateNotes } = await import(process.argv[1]);
        const result = await generateNotes({}, {
          commits: [],
          lastRelease: { version: process.argv[2] === "-" ? "" : process.argv[2] },
          nextRelease: { version: process.argv[3] },
          env: { CALRELAY_RELEASE_BOOTSTRAP: process.argv[4] },
        });
        process.stdout.write(result);
        """
        return try Self.run(
            executable: "/usr/bin/env",
            arguments: [
                "node", "--input-type=module", "--eval", script, plugin, lastVersion ?? "-", nextVersion,
                bootstrap ? "1" : "0"
            ],
            directory: sourceRoot)
    }

    func runSemanticReleaseRunner(arguments: [String]) throws -> ReleaseProcessResult {
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let node = bin.appendingPathComponent("node")
        let npx = bin.appendingPathComponent("npx")
        let fakeNode = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
          printf 'v24.21.0\\n'
        elif [ "$1" = "-e" ]; then
          case "$2" in
            *data.node*) printf '24.21.0' ;;
            *data.semanticRelease*) printf '25.0.9' ;;
            *) exit 64 ;;
          esac
        else
          exit 64
        fi
        """
        let fakeNpx = """
        #!/bin/sh
        printf 'bootstrap=%s\\n' "${CALRELAY_RELEASE_BOOTSTRAP-unset}"
        printf 'args='
        printf '<%s>' "$@"
        printf '\\n'
        """
        try Data(fakeNode.utf8).write(to: node)
        try Data(fakeNpx.utf8).write(to: npx)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: node.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: npx.path)

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "\(bin.path):\(environment["PATH"] ?? "")"
        return try Self.run(
            executable: "/bin/zsh",
            arguments: [sourceRoot.appendingPathComponent("scripts/release/run-semantic-release.sh").path] + arguments,
            directory: sourceRoot,
            environment: environment)
    }

    @discardableResult
    func git(_ arguments: [String]) throws -> ReleaseProcessResult {
        let result = try Self.run(executable: "/usr/bin/git", arguments: ["-C", root.path] + arguments, directory: root)
        guard result.status == 0 else { throw TestFailure("git \(arguments.joined(separator: " ")) failed: \(result.output)") }
        return result
    }

    func read(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private func writeVersion(_ version: String) throws {
        try Data(version.utf8).write(to: root.appendingPathComponent("VERSION"))
        let generated = "enum GeneratedReleaseVersion {\n    static let value = \"\(version)\"\n}\n"
        try Data(generated.utf8).write(to: root.appendingPathComponent("Sources/CalRelayCLI/GeneratedReleaseVersion.swift"))
    }

    private static func run(
        executable: String,
        arguments: [String],
        directory: URL,
        environment: [String: String]? = nil
    ) throws -> ReleaseProcessResult {
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
        return ReleaseProcessResult(status: process.terminationStatus, output: output)
    }

    private static func repositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) {
                return candidate
            }
            candidate = candidate.deletingLastPathComponent()
        }
        throw TestFailure("Unable to resolve the repository root from #filePath")
    }
}

private struct ReleaseProcessResult {
    let status: Int32
    let output: String
}