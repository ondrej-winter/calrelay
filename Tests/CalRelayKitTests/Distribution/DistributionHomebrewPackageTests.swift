import Foundation

enum DistributionHomebrewPackageTests {
    static func runAll() throws {
        try testVerifiedManifestRendersAtomicFormulaAndCask()
        try testInvalidManifestAndMismatchedOutputFailClosed()
        try testManifestSchemaRejectsUnexpectedFields()
        try testLifecycleValidationCoversCoexistenceUpgradeAndCleanup()
        try testLifecycleFailureCleansPackagesTapAndWorkDirectory()
    }

    private static func testVerifiedManifestRendersAtomicFormulaAndCask() throws {
        let fixture = try HomebrewPackageFixture()
        defer { fixture.remove() }

        let result = try fixture.run()
        try expect(result.status == 0, "Homebrew package generation must succeed: \(result.output)")

        let formulaURL = fixture.output.appendingPathComponent("Formula/calrelay.rb")
        let caskURL = fixture.output.appendingPathComponent("Casks/calrelay.rb")
        let formula = try String(contentsOf: formulaURL, encoding: .utf8)
        let cask = try String(contentsOf: caskURL, encoding: .utf8)

        try expect(formula.contains("class Calrelay < Formula"), "Formula token must be calrelay")
        try expect(cask.contains("cask \"calrelay\" do"), "Cask token must be calrelay")
        for contents in [formula, cask] {
            try expect(contents.contains("version \"1.2.3\""), "Both packages must use the manifest version")
            try expect(contents.contains("depends_on arch: :arm64"), "Both packages must require Apple Silicon")
            try expect(contents.contains("depends_on macos: :tahoe"), "Both packages must require macOS 26 or later")
            try expect(contents.contains("livecheck do") && contents.contains("skip \""), "Version discovery must be disabled")
        }

        try expect(formula.contains(fixture.cliDigest), "Formula must use the verified CLI digest")
        try expect(formula.contains("calrelay-1.2.3-arm64.tar.gz"), "Formula must download the versioned CLI artifact")
        try expect(formula.contains("bin.install \"calrelay\""), "Formula must install only calrelay")
        try expect(formula.contains("--version") && formula.contains("--help"), "Formula must smoke test version and help")
        try expect(formula.range(of: "swift", options: .caseInsensitive) == nil, "Formula must not invoke SwiftPM")
        try expect(!formula.contains("CalRelay.app"), "Formula must not install the app")

        try expect(cask.contains(fixture.appDigest), "Cask must use the verified app digest")
        try expect(cask.contains("CalRelay-1.2.3-arm64.zip"), "Cask must download the versioned app artifact")
        try expect(cask.contains("app \"CalRelay.app\""), "Cask must install only CalRelay.app")
        try expect(!cask.contains("binary "), "Cask must not install the CLI")
        try expect(!cask.contains("zap "), "Cask must not define a destructive zap")

        let retry = try fixture.run()
        try expect(retry.status == 0, "A matching same-version retry must be idempotent: \(retry.output)")
    }

    private static func testInvalidManifestAndMismatchedOutputFailClosed() throws {
        let wrongArch = try HomebrewPackageFixture(architecture: "x86_64")
        defer { wrongArch.remove() }
        let archResult = try wrongArch.run()
        try expect(archResult.status != 0, "Non-arm64 manifests must be rejected")
        try expect(!FileManager.default.fileExists(atPath: wrongArch.output.path), "Invalid input must not leave partial output")

        let badDigest = try HomebrewPackageFixture(cliDigestOverride: String(repeating: "0", count: 64))
        defer { badDigest.remove() }
        let digestResult = try badDigest.run()
        try expect(digestResult.status != 0, "Manifest digests must match exact artifact bytes")
        try expect(digestResult.output.contains("SHA-256"), "Digest failures must explain the mismatch")

        let mismatched = try HomebrewPackageFixture()
        defer { mismatched.remove() }
        let initial = try mismatched.run()
        try expect(initial.status == 0, "Initial package generation must succeed: \(initial.output)")
        let formula = mismatched.output.appendingPathComponent("Formula/calrelay.rb")
        let handle = try FileHandle(forWritingTo: formula)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n# unexpected\n".utf8))
        let mismatchResult = try mismatched.run()
        try expect(mismatchResult.status != 0, "A retry must reject mismatched package content")
        try expect(
            FileManager.default.fileExists(atPath: mismatched.output.appendingPathComponent("Casks/calrelay.rb").path),
            "A rejected retry must preserve the matching cask")
    }

    private static func testManifestSchemaRejectsUnexpectedFields() throws {
        let unexpectedRoot = try HomebrewPackageFixture(extraManifestValues: ["unexpected": true])
        defer { unexpectedRoot.remove() }
        let rootResult = try unexpectedRoot.run()
        try expect(rootResult.status != 0, "Unexpected candidate-manifest fields must be rejected")
        try expect(!FileManager.default.fileExists(atPath: unexpectedRoot.output.path), "Rejected schemas must emit nothing")

        let unexpectedArtifact = try HomebrewPackageFixture(extraCLIValues: ["url": "https://example.invalid/artifact"])
        defer { unexpectedArtifact.remove() }
        let artifactResult = try unexpectedArtifact.run()
        try expect(artifactResult.status != 0, "Unexpected artifact fields must be rejected")
        try expect(
            !FileManager.default.fileExists(atPath: unexpectedArtifact.output.path),
            "Rejected artifact schemas must emit nothing")
    }

    private static func testLifecycleValidationCoversCoexistenceUpgradeAndCleanup() throws {
        let fixture = try HomebrewLifecycleFixture()
        defer { fixture.remove() }

        let result = try fixture.run()

        try expect(result.status == 0, "Fake-backed Homebrew lifecycle validation must succeed: \(result.output)")
        let log = try String(contentsOf: fixture.log, encoding: .utf8)
        for required in [
            "style --formula ondrej-winter/tap/calrelay", "style --cask ondrej-winter/tap/calrelay",
            "audit --strict --formula --except=version ondrej-winter/tap/calrelay",
            "audit --strict --cask --except=sha256_no_check_if_unversioned ondrej-winter/tap/calrelay",
            "fetch --retry --formula ondrej-winter/tap/calrelay",
            "fetch --retry --cask ondrej-winter/tap/calrelay", "test ondrej-winter/tap/calrelay",
            "upgrade --formula ondrej-winter/tap/calrelay", "upgrade --cask ondrej-winter/tap/calrelay",
            "reinstall --formula ondrej-winter/tap/calrelay", "reinstall --cask ondrej-winter/tap/calrelay",
            "list --versions --formula calrelay", "list --versions --cask calrelay",
            "untap ondrej-winter/tap",
        ] {
            try expect(log.contains(required), "Lifecycle validation must run \(required)")
        }
        let installLines = log.split(separator: "\n").map(String.init).filter { $0.hasPrefix("install ") }
        try expect(
            installLines == [
                "install --formula ondrej-winter/tap/calrelay",
                "install --cask ondrej-winter/tap/calrelay --appdir \(fixture.appDirectory.path)",
                "install --cask ondrej-winter/tap/calrelay --appdir \(fixture.appDirectory.path)",
                "install --formula ondrej-winter/tap/calrelay",
            ],
            "Lifecycle validation must install both packages in both orders")
        try expect(!log.contains(" open ") && !log.contains("swift"), "Package validation must not launch products or invoke Swift")
        let retainedSentinel = try fixture.readSentinel()
        let installedPackages = try fixture.installedPackages()
        try expect(retainedSentinel == fixture.sentinel, "Package operations must preserve user state")
        try expect(installedPackages.isEmpty, "Lifecycle validation must clean all installed test packages")
    }

    private static func testLifecycleFailureCleansPackagesTapAndWorkDirectory() throws {
        let fixture = try HomebrewLifecycleFixture(
            failureCommandPrefix: "upgrade --cask ondrej-winter/tap/calrelay", retainOldFormulaOnUpgrade: true)
        defer { fixture.remove() }

        let result = try fixture.run()
        let preservedSentinel = try fixture.readSentinel()
        let installedPackages = try fixture.installedPackages()

        try expect(result.status != 0, "A Homebrew lifecycle command failure must fail validation")
        try expect(preservedSentinel == fixture.sentinel, "Failed package validation must preserve user state")
        try expect(installedPackages.isEmpty, "Failed package validation must uninstall temporary packages")
        try expect(!FileManager.default.fileExists(atPath: fixture.work.path), "Failed package validation must remove work")
        let log = try String(contentsOf: fixture.log, encoding: .utf8)
        try expect(log.contains("uninstall --force --formula"), "Failure cleanup must remove every temporary formula version")
        try expect(log.contains("uninstall --cask"), "Failure cleanup must remove the temporary cask")
        try expect(log.contains("untap ondrej-winter/tap"), "Failure cleanup must remove the temporary tap")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}

private struct HomebrewPackageFixture {
    let sourceRoot: URL
    let root: URL
    let artifacts: URL
    let manifest: URL
    let output: URL
    let cliDigest: String
    let appDigest: String

    init(
        architecture: String = "arm64", cliDigestOverride: String? = nil,
        extraManifestValues: [String: Any] = [:], extraCLIValues: [String: Any] = [:]
    ) throws {
        sourceRoot = try Self.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("calrelay-homebrew-\(UUID().uuidString)")
        artifacts = root.appendingPathComponent("artifacts")
        manifest = root.appendingPathComponent("candidate-manifest.json")
        output = root.appendingPathComponent("tap-packages")
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)

        let cliURL = artifacts.appendingPathComponent("calrelay-1.2.3-arm64.tar.gz")
        let appURL = artifacts.appendingPathComponent("CalRelay-1.2.3-arm64.zip")
        try Data("cli-artifact-bytes".utf8).write(to: cliURL)
        try Data("app-artifact-bytes".utf8).write(to: appURL)
        cliDigest = try Self.sha256(cliURL)
        appDigest = try Self.sha256(appURL)

        var cli: [String: Any] = ["name": cliURL.lastPathComponent, "sha256": cliDigestOverride ?? cliDigest]
        for (key, value) in extraCLIValues { cli[key] = value }
        var value: [String: Any] = [
            "schemaVersion": 1,
            "version": "1.2.3",
            "architecture": architecture,
            "minimumMacOS": "26.0",
            "sdk": "27.0",
            "cli": cli,
            "app": ["name": appURL.lastPathComponent, "sha256": appDigest],
        ]
        for (key, extra) in extraManifestValues { value[key] = extra }
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: manifest)
    }

    func run() throws -> HomebrewPackageProcessResult {
        try Self.run(
            executable: "/usr/bin/env",
            arguments: [
                "node", sourceRoot.appendingPathComponent("scripts/release/generate-homebrew-packages.mjs").path,
                "--manifest", manifest.path,
                "--artifacts-directory", artifacts.path,
                "--output-directory", output.path,
            ])
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private static func sha256(_ url: URL) throws -> String {
        let result = try run(executable: "/usr/bin/shasum", arguments: ["-a", "256", url.path])
        guard result.status == 0, let digest = result.output.split(whereSeparator: { $0.isWhitespace }).first else {
            throw TestFailure("Unable to digest fixture artifact")
        }
        return String(digest)
    }

    private static func run(executable: String, arguments: [String]) throws -> HomebrewPackageProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return HomebrewPackageProcessResult(status: process.terminationStatus, output: output)
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

private final class HomebrewLifecycleFixture {
    let sourceRoot: URL
    let root: URL
    let currentPackages: URL
    let previousPackages: URL
    let work: URL
    let log: URL
    let state: URL
    let appDirectory: URL
    let sentinel = "CONFIGURATION-AND-APP-STATE-SENTINEL"
    private let brew: URL
    private let failureCommandPrefix: String?
    private let retainOldFormulaOnUpgrade: Bool

    init(failureCommandPrefix: String? = nil, retainOldFormulaOnUpgrade: Bool = false) throws {
        self.failureCommandPrefix = failureCommandPrefix
        self.retainOldFormulaOnUpgrade = retainOldFormulaOnUpgrade
        sourceRoot = try Self.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("calrelay-homebrew-lifecycle-\(UUID().uuidString)")
        currentPackages = root.appendingPathComponent("current")
        previousPackages = root.appendingPathComponent("previous")
        work = root.appendingPathComponent("work")
        log = root.appendingPathComponent("brew.log")
        state = root.appendingPathComponent("state")
        appDirectory = work.appendingPathComponent("Applications")
        brew = root.appendingPathComponent("fake-brew")
        try FileManager.default.createDirectory(at: currentPackages.appendingPathComponent("Formula"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: currentPackages.appendingPathComponent("Casks"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: previousPackages.appendingPathComponent("Formula"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: previousPackages.appendingPathComponent("Casks"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        for packages in [currentPackages, previousPackages] {
            try Data("class Calrelay < Formula\nend\n".utf8).write(
                to: packages.appendingPathComponent("Formula/calrelay.rb"))
            try Data("cask \"calrelay\" do\nend\n".utf8).write(
                to: packages.appendingPathComponent("Casks/calrelay.rb"))
        }
        try Data(sentinel.utf8).write(to: state.appendingPathComponent("config.yaml"))
        try Data(sentinel.utf8).write(to: state.appendingPathComponent("app-state"))
        try writeFakeBrew()
    }

    func run() throws -> HomebrewPackageProcessResult {
        var environment = ProcessInfo.processInfo.environment
        environment["CALRELAY_FAKE_BREW_LOG"] = log.path
        environment["CALRELAY_FAKE_BREW_STATE"] = root.appendingPathComponent("installed").path
        environment["CALRELAY_FAKE_TAP_CHECKOUT"] = root.appendingPathComponent("tap-checkout").path
        environment["CALRELAY_FAKE_BREW_FAILURE_COMMAND_PREFIX"] = failureCommandPrefix ?? ""
        environment["CALRELAY_FAKE_BREW_RETAIN_OLD_FORMULA"] = retainOldFormulaOnUpgrade ? "1" : ""
        environment["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        return try Self.run(
            executable: "/usr/bin/env",
            arguments: [
                "node", sourceRoot.appendingPathComponent("scripts/release/validate-homebrew-packages.mjs").path,
                "--packages-directory", currentPackages.path,
                "--previous-packages-directory", previousPackages.path,
                "--work-directory", work.path,
                "--state-directory", state.path,
                "--brew", brew.path,
            ], environment: environment)
    }

    func readSentinel() throws -> String {
        let config = try String(contentsOf: state.appendingPathComponent("config.yaml"), encoding: .utf8)
        let appState = try String(contentsOf: state.appendingPathComponent("app-state"), encoding: .utf8)
        guard config == appState else { throw TestFailure("Sentinel files diverged") }
        return config
    }

    func installedPackages() throws -> [String] {
        let directory = root.appendingPathComponent("installed")
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private func writeFakeBrew() throws {
        let contents = """
        #!/bin/sh
        set -eu
        printf '%s\\n' "$*" >> "$CALRELAY_FAKE_BREW_LOG"
        case "$*" in
          "${CALRELAY_FAKE_BREW_FAILURE_COMMAND_PREFIX:-}"*)
            [ -n "${CALRELAY_FAKE_BREW_FAILURE_COMMAND_PREFIX:-}" ] && exit 70
            ;;
        esac
        mkdir -p "$CALRELAY_FAKE_BREW_STATE"
        command="$1"
        shift
        if [ "$command" = "--repo" ]; then
          mkdir -p "$CALRELAY_FAKE_TAP_CHECKOUT"
          printf '%s\\n' "$CALRELAY_FAKE_TAP_CHECKOUT"
          exit 0
        fi
        kind=formula
        for argument in "$@"; do
          [ "$argument" = "--cask" ] && kind=cask
        done
        case "$command" in
          install|reinstall)
            : > "$CALRELAY_FAKE_BREW_STATE/$kind-current"
            ;;
          upgrade)
            if [ "$kind" = formula ]; then
              [ ! -f "$CALRELAY_FAKE_BREW_STATE/formula-current" ] || : > "$CALRELAY_FAKE_BREW_STATE/formula-old"
              : > "$CALRELAY_FAKE_BREW_STATE/formula-current"
              if [ -z "${HOMEBREW_NO_INSTALL_CLEANUP:-}" ] && [ -z "${CALRELAY_FAKE_BREW_RETAIN_OLD_FORMULA:-}" ]; then
                rm -f "$CALRELAY_FAKE_BREW_STATE/formula-old"
              fi
            else
              : > "$CALRELAY_FAKE_BREW_STATE/cask-current"
            fi
            ;;
          uninstall)
            force=false
            for argument in "$@"; do
              [ "$argument" != "--force" ] || force=true
            done
            rm -f "$CALRELAY_FAKE_BREW_STATE/$kind-current"
            [ "$kind" != formula ] || [ "$force" != true ] || rm -f "$CALRELAY_FAKE_BREW_STATE/formula-old"
            ;;
          list)
            if [ "$kind" = formula ]; then
              [ -f "$CALRELAY_FAKE_BREW_STATE/formula-current" ] || [ -f "$CALRELAY_FAKE_BREW_STATE/formula-old" ] || exit 1
            else
              [ -f "$CALRELAY_FAKE_BREW_STATE/cask-current" ] || exit 1
            fi
            printf 'calrelay 1.2.3\\n'
            ;;
          style|audit|fetch|test|tap|untap)
            ;;
          *)
            printf 'unexpected fake brew command: %s\\n' "$command" >&2
            exit 64
            ;;
        esac
        """
        try Data(contents.utf8).write(to: brew)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: brew.path)
    }

    private static func run(
        executable: String, arguments: [String], environment: [String: String]
    ) throws -> HomebrewPackageProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return HomebrewPackageProcessResult(status: process.terminationStatus, output: output)
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

private struct HomebrewPackageProcessResult {
    let status: Int32
    let output: String
}
