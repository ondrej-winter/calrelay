import Foundation

enum DistributionProductionArtifactTests {
    static func runAll() throws {
        try testProductionPackagingContractIsSeparateAndCredentialSafe()
        try testFakeReleaseBuildProducesVerifiedVersionedArtifacts()
        try testFakeReleaseBuildRejectsBoundaryFailuresAndCleansKeychain()
        try testProhibitedProductDataLeavesNoFinalArtifacts()
    }

    private static func testProductionPackagingContractIsSeparateAndCredentialSafe() throws {
        let root = try repositoryRoot()
        let script = try String(
            contentsOf: root.appendingPathComponent("scripts/release/build-production-artifacts.sh"), encoding: .utf8)
        let local = try String(
            contentsOf: root.appendingPathComponent("scripts/build-calrelay-app.sh"), encoding: .utf8)
        try expect(
            !local.contains("CALRELAY_DEVELOPER_ID_P12"),
            "Local app packaging must remain independent of production credentials")
        for required in [
            "CALRELAY_DEVELOPER_ID_P12", "CALRELAY_DEVELOPER_ID_P12_PASSWORD", "CALRELAY_NOTARY_API_KEY_P8",
            "CALRELAY_NOTARY_KEY_ID", "CALRELAY_NOTARY_ISSUER_ID", "CALRELAY_DEVELOPER_TEAM_ID",
            "CALRELAY_SIGNING_CERTIFICATE_SHA1"
        ] { try expect(script.contains(required), "Production packaging must require \(required)") }
        try expect(
            !script.contains("CALRELAY_SIGNING_IDENTITY"),
            "Production signing must not select a certificate by its potentially non-ASCII display name")
        try expect(
            script.contains("create-keychain") && script.contains("delete-keychain"),
            "Production signing must use an ephemeral keychain with cleanup")
        try expect(
            script.contains("find-identity") && script.contains("codesigning"),
            "Production signing must verify the configured certificate fingerprint in the ephemeral keychain")
        try expect(
            script.contains("--options runtime") && script.contains("--timestamp"),
            "Both products must use hardened runtime and secure timestamps")
        try expect(
            script.contains("notarytool") && script.contains("stapler") && script.contains("spctl"),
            "Production packaging must notarize, staple, and assess the app")
        guard let staple = script.range(of: "\"${STAPLER}\" staple")?.lowerBound,
            let sensitiveScan = script.range(of: "scan_value \"${CALRELAY_DEVELOPER_ID_P12_PASSWORD}\"")?.lowerBound,
            let cliPackage = script.range(of: "COPYFILE_DISABLE=1 /usr/bin/tar -czf")?.lowerBound,
            let appPackage = script.range(
                of: "COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --keepParent \"${APP_BUNDLE}\" \"${STAGED_APP_ARCHIVE}\"")?
                .lowerBound, let checksums = script.range(of: "CLI_SHA=")?.lowerBound
        else { throw TestFailure("Production packaging must expose stapling, final packaging, and checksum stages") }
        try expect(
            staple < sensitiveScan && sensitiveScan < cliPackage && sensitiveScan < appPackage && cliPackage < checksums
                && appPackage < checksums,
            "Products must be scanned before private archive staging, with checksums computed after final packaging")
    }

    private static func testFakeReleaseBuildProducesVerifiedVersionedArtifacts() throws {
        let fixture = try ProductionArtifactFixture(version: "1.2.3")
        defer { fixture.remove() }
        let result = try fixture.run()
        try expect(result.status == 0, "Fake production packaging must succeed: \(result.output)")
        let cli = fixture.output.appendingPathComponent("calrelay-1.2.3-arm64.tar.gz")
        let app = fixture.output.appendingPathComponent("CalRelay-1.2.3-arm64.zip")
        try expect(FileManager.default.fileExists(atPath: cli.path), "The versioned CLI archive must be emitted")
        try expect(FileManager.default.fileExists(atPath: app.path), "The versioned app archive must be emitted")
        let manifest = try JSONDecoder().decode(
            CandidateManifest.self,
            from: Data(contentsOf: fixture.output.appendingPathComponent("candidate-manifest.json")))
        try expect(manifest.version == "1.2.3", "Candidate manifest must retain the synchronized release version")
        try expect(
            manifest.cli.name == cli.lastPathComponent && manifest.app.name == app.lastPathComponent,
            "Manifest names must match final immutable artifacts")
        try expect(
            manifest.cli.sha256.count == 64 && manifest.app.sha256.count == 64,
            "Final artifacts must have SHA-256 digests")
        let cliEntries = try fixture.command("/usr/bin/tar", ["-tzf", cli.path])
        try expect(cliEntries.output == "calrelay\n", "CLI archive must contain exactly one executable named calrelay")
        let appEntries = try fixture.command("/usr/bin/zipinfo", ["-1", app.path])
        try expect(
            appEntries.output.split(separator: "\n").allSatisfy { $0.hasPrefix("CalRelay.app/") },
            "App archive must contain only CalRelay.app")
        let log = try String(contentsOf: fixture.toolLog, encoding: .utf8)
        try expect(
            log.contains("codesign --force --options runtime --timestamp"),
            "Signing must request hardened runtime and timestamp")
        try expect(
            log.contains("--entitlements") && log.contains("CalRelayApp.entitlements"),
            "App signing must apply the production Calendar entitlement file")
        try expect(
            log.contains("security find-identity -v -p codesigning")
                && log.contains("--sign \(fixture.signingCertificateSHA1)"),
            "Signing must verify and select the imported certificate by its SHA-1 fingerprint")
        try expect(
            log.contains("swift build --sdk \(fixture.sdkPath) -c release --arch arm64 --product calrelay")
                && log.contains("swift build --sdk \(fixture.sdkPath) -c release --arch arm64 --product CalRelayApp"),
            "Both products must explicitly build with the selected macOS 27 SDK")
        try expect(
            log.contains("notarytool submit") && log.contains("stapler staple") && log.contains("spctl --assess"),
            "Protected verification stages must all run")
        try expect(log.contains("security delete-keychain"), "The ephemeral keychain must be removed after success")
        try expect(!log.contains(fixture.secretSentinel), "Fake release logs must redact protected values")
        try expect(
            !FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent(".work").path),
            "Ephemeral signing work must be removed after success")
        try expect(!result.output.contains(fixture.secretSentinel), "Release output must not disclose protected values")
        try expect(
            !result.output.contains("swift-driver version"),
            "Captured Swift version diagnostics must not run into later release output")
    }

    private static func testFakeReleaseBuildRejectsBoundaryFailuresAndCleansKeychain() throws {
        for failure in [
            "toolchain", "identity", "architecture", "deployment", "team", "codesign", "entitlement", "notary",
            "stapler"
        ] {
            let fixture = try ProductionArtifactFixture(version: "1.2.4", failure: failure)
            let result = try fixture.run()
            let log = (try? String(contentsOf: fixture.toolLog, encoding: .utf8)) ?? ""
            let workRemoved = !FileManager.default.fileExists(
                atPath: fixture.output.appendingPathComponent(".work").path)
            fixture.remove()
            try expect(result.status != 0, "Production packaging must reject \(failure) failures")
            if failure != "toolchain" {
                try expect(
                    log.contains("security delete-keychain"),
                    "The ephemeral keychain must be removed after \(failure) failure. Log: \(log)")
            }
            try expect(workRemoved, "Ephemeral signing work must be removed after \(failure) failure")
            try expect(
                !log.contains(fixture.secretSentinel),
                "Fake release logs must redact protected values after \(failure) failure")
            try expect(
                !result.output.contains(fixture.secretSentinel),
                "Failure diagnostics must not disclose protected values")
            if failure == "identity" {
                try expect(
                    result.output.contains("expected Developer ID Application signing certificate"),
                    "Identity mismatch diagnostics must explain the missing configured certificate")
                try expect(
                    !log.contains("swift build"),
                    "A missing imported signing identity must fail before compiling release products")
            } else if failure == "deployment" {
                try expect(
                    result.output.contains("macOS 26 as the minimum deployment target"),
                    "Deployment mismatch diagnostics must explain the required minimum macOS version")
            }
        }

        let malformed = try ProductionArtifactFixture(version: "v1.2.3")
        defer { malformed.remove() }
        let result = try malformed.run()
        try expect(
            result.status != 0 && result.output.contains("canonical X.Y.Z"),
            "Malformed release versions must fail before packaging")

        let malformedCertificate = try ProductionArtifactFixture(
            version: "1.2.3", signingCertificateSHA1: "not-a-certificate-fingerprint")
        defer { malformedCertificate.remove() }
        let malformedCertificateResult = try malformedCertificate.run()
        try expect(
            malformedCertificateResult.status != 0
                && malformedCertificateResult.output.contains("40 hexadecimal characters"),
            "Malformed signing certificate fingerprints must fail before keychain import")
    }

    private static func testProhibitedProductDataLeavesNoFinalArtifacts() throws {
        let sentinels = [
            "PRIVATE-SENTINEL", "CONFIGURATION-CONTENT-SENTINEL", "CALENDAR-NAME-SENTINEL",
            "EVENT-TITLE-SENTINEL", "EVENTKIT-IDENTIFIER-SENTINEL",
        ]
        for (index, injectedSentinel) in sentinels.enumerated() {
            let version = "1.2.\(index + 5)"
            let fixture = try ProductionArtifactFixture(version: version, prohibitedProductSentinel: injectedSentinel)
            defer { fixture.remove() }

            let result = try fixture.run()
            let log = (try? String(contentsOf: fixture.toolLog, encoding: .utf8)) ?? ""

            try expect(result.status != 0, "Products containing prohibited private data must fail packaging")
            try expect(
                result.output.contains("prohibited sensitive release data"),
                "Sensitive-data rejection must explain the privacy boundary without disclosing the value")
            for sentinel in fixture.prohibitedSentinels {
                try expect(!result.output.contains(sentinel), "Sensitive-data diagnostics must not disclose \(sentinel)")
                try expect(!log.contains(sentinel), "Release tool logs must not disclose \(sentinel)")
            }
            try expect(!result.output.contains(fixture.secretSentinel), "Sensitive-data diagnostics must not disclose credentials")
            try expect(!log.contains(fixture.secretSentinel), "Release tool logs must not disclose credentials")
            for name in [
                "calrelay-\(version)-arm64.tar.gz", "CalRelay-\(version)-arm64.zip", "candidate-manifest.json"
            ] {
                try expect(
                    !FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent(name).path),
                    "Rejected private data must not leave final release output \(name)")
            }
            try expect(
                !FileManager.default.fileExists(atPath: fixture.output.appendingPathComponent(".work").path),
                "Sensitive-data failure must remove ephemeral signing work")
            try expect(
                !FileManager.default.fileExists(
                    atPath: fixture.root.appendingPathComponent(".build/release/calrelay").path),
                "Sensitive-data failure must remove the generated release product from the build cache")
        }
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

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message) }
    }
}

private struct CandidateManifest: Decodable {
    struct Artifact: Decodable {
        let name: String
        let sha256: String
    }
    let version: String
    let cli: Artifact
    let app: Artifact
}

private struct ArtifactProcessResult {
    let status: Int32
    let output: String
}

private final class ProductionArtifactFixture {
    let root: URL
    let output: URL
    let toolLog: URL
    let signingCertificateSHA1: String
    var sdkPath: String { tools.appendingPathComponent("MacOSX27.0.sdk").path }
    let secretSentinel = "PRIVATE-SENTINEL"
    let prohibitedSentinels = [
        "CONFIGURATION-CONTENT-SENTINEL", "CALENDAR-NAME-SENTINEL", "EVENT-TITLE-SENTINEL",
        "EVENTKIT-IDENTIFIER-SENTINEL",
    ]
    private let tools: URL
    private let failure: String?
    private let prohibitedProductSentinel: String?
    private let version: String

    init(
        version: String, failure: String? = nil, prohibitedProductSentinel: String? = nil,
        signingCertificateSHA1: String = "0123456789ABCDEF0123456789ABCDEF01234567"
    ) throws {
        self.version = version
        self.failure = failure
        self.prohibitedProductSentinel = prohibitedProductSentinel
        self.signingCertificateSHA1 = signingCertificateSHA1
        let source = try DistributionProductionArtifactTests.repositoryRoot()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DistributionProductionArtifactTests-\(UUID().uuidString)")
        output = root.appendingPathComponent("output")
        tools = root.appendingPathComponent("tools")
        toolLog = root.appendingPathComponent("tool.log")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("scripts/release"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Resources/CalRelayApp"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources/CalRelayCLI"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: tools.appendingPathComponent("MacOSX27.0.sdk"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: source.appendingPathComponent("scripts/release/build-production-artifacts.sh"),
            to: root.appendingPathComponent("scripts/release/build-production-artifacts.sh"))
        try FileManager.default.copyItem(
            at: source.appendingPathComponent("Resources/CalRelayApp/Info.plist"),
            to: root.appendingPathComponent("Resources/CalRelayApp/Info.plist"))
        try FileManager.default.copyItem(
            at: source.appendingPathComponent("Resources/CalRelayApp/CalRelayApp.entitlements"),
            to: root.appendingPathComponent("Resources/CalRelayApp/CalRelayApp.entitlements"))
        try Data(version.utf8).write(to: root.appendingPathComponent("VERSION"))
        try Data("// swift-tools-version: 6.4\nplatforms: [.macOS(.v26)]\n".utf8).write(
            to: root.appendingPathComponent("Package.swift"))
        try writeTools()
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func run() throws -> ArtifactProcessResult {
        var environment = ProcessInfo.processInfo.environment
        environment["CALRELAY_RELEASE_TESTING"] = "1"
        environment["CALRELAY_RELEASE_TEST_TOOLS_DIR"] = tools.path
        environment["CALRELAY_RELEASE_OUTPUT_DIR"] = output.path
        environment["CALRELAY_RELEASE_TOOL_LOG"] = toolLog.path
        environment["CALRELAY_RELEASE_FAKE_FAILURE"] = failure ?? ""
        environment["CALRELAY_RELEASE_FAKE_PROHIBITED_SENTINEL"] = prohibitedProductSentinel ?? ""
        environment["CALRELAY_DEVELOPER_ID_P12"] = Data(secretSentinel.utf8).base64EncodedString()
        environment["CALRELAY_DEVELOPER_ID_P12_PASSWORD"] = secretSentinel
        environment["CALRELAY_NOTARY_API_KEY_P8"] = secretSentinel
        environment["CALRELAY_NOTARY_KEY_ID"] = "KEY123"
        environment["CALRELAY_NOTARY_ISSUER_ID"] = "ISSUER123"
        environment["CALRELAY_DEVELOPER_TEAM_ID"] = "TEAM123456"
        environment["CALRELAY_SIGNING_CERTIFICATE_SHA1"] = signingCertificateSHA1
        environment["CALRELAY_RELEASE_PROHIBITED_SENTINELS"] = prohibitedSentinels.joined(separator: "\n")
        return try command(
            "/bin/zsh", [root.appendingPathComponent("scripts/release/build-production-artifacts.sh").path],
            environment: environment)
    }

    func command(_ executable: String, _ arguments: [String], environment: [String: String]? = nil) throws
        -> ArtifactProcessResult
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ArtifactProcessResult(status: process.terminationStatus, output: output)
    }

    private func writeTools() throws {
        let common =
            "#!/bin/zsh\nlogged=\"$*\"\nlogged=\"${logged//${CALRELAY_DEVELOPER_ID_P12_PASSWORD}/<redacted>}\"\nlogged=\"${logged//${CALRELAY_NOTARY_API_KEY_P8}/<redacted>}\"\nprint -r -- \"${0:t} $logged\" >> \"${CALRELAY_RELEASE_TOOL_LOG}\"\n"
        try writeTool(
            "xcodebuild",
            common
                + "[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == toolchain ]] && print \"Xcode 26.4\" || print \"Xcode 27.0\"\nprint \"Build version 27A266a\"\n"
        )
        try writeTool("sw_vers", common + "print \"27.0\"\n")
        try writeTool("uname", common + "print arm64\n")
        try writeTool(
            "swift",
            common
                + "if [[ \"$1\" == --version ]]; then print -nu2 \"swift-driver version: 1.168.6 \"; print \"Apple Swift version 6.4\"; print \"Target: arm64-apple-macosx27.0.0\"; exit 0; fi\nproduct=\"\"\nwhile (( $# )); do [[ \"$1\" == --product ]] && { shift; product=\"$1\"; }; shift || true; done\nmkdir -p .build/release\nif [[ \"$product\" == calrelay ]]; then printf \"%s\\n\" \"#!/bin/zsh\" \"[[ \\\"\\$1\\\" == --version ]] && print \(version)\" \"exit 0\" > .build/release/calrelay; [[ -n \"${CALRELAY_RELEASE_FAKE_PROHIBITED_SENTINEL}\" ]] && print -r -- \"# ${CALRELAY_RELEASE_FAKE_PROHIBITED_SENTINEL}\" >> .build/release/calrelay; chmod 755 .build/release/calrelay; else printf \"%s\\n\" \"#!/bin/zsh\" \"exit 0\" > .build/release/CalRelayApp; chmod 755 .build/release/CalRelayApp; fi\n"
        )
        try writeTool(
            "security",
            common
                + "if [[ \"$1\" == create-keychain ]]; then touch \"${@: -1}\"; fi\nif [[ \"$1\" == find-identity ]]; then\n    if [[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == identity ]]; then\n        print \"     0 valid identities found\"\n    else\n        print \"  1) ${CALRELAY_SIGNING_CERTIFICATE_SHA1} \\\"Developer ID Application: CalRelay Test\\\"\"\n        print \"     1 valid identities found\"\n    fi\nfi\nexit 0\n")
        try writeTool(
            "codesign",
            common
                + "[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == codesign && \"$1\" == --force ]] && exit 2\nif [[ \"$1\" == -dv ]]; then [[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == team ]] && team=WRONGTEAM || team=TEAM123456; print -u2 \"TeamIdentifier=$team\"; print -u2 \"flags=0x10000(runtime)\"; print -u2 \"Timestamp=Sep 26, 2026\"; fi\nif [[ \"$1\" == -d && \"$2\" == --entitlements ]]; then [[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == entitlement ]] && calendar=\"\" || calendar=\"<key>com.apple.security.personal-information.calendars</key><true/>\"; print \"<?xml version=\\\"1.0\\\"?><plist><dict>${calendar}</dict></plist>\"; fi\nexit 0\n"
        )
        try writeTool(
            "lipo",
            common + "[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == architecture ]] && print x86_64 || print arm64\n")
        try writeTool(
            "vtool",
            common
                + "print \"platform MACOS\"\n[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == deployment ]] && print \"minos 27.0\" || print \"minos 26.0\"\nprint \"sdk 26.0\"\n")
        try writeTool(
            "notarytool",
            common
                + "[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == notary ]] && print \"{\\\"status\\\":\\\"Invalid\\\"}\" || print \"{\\\"status\\\":\\\"Accepted\\\"}\"\n"
        )
        try writeTool("stapler", common + "[[ \"${CALRELAY_RELEASE_FAKE_FAILURE}\" == stapler ]] && exit 3 || exit 0\n")
        try writeTool("spctl", common + "exit 0\n")
    }

    private func writeTool(_ name: String, _ contents: String) throws {
        let url = tools.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
