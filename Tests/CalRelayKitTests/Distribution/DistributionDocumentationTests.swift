import Foundation

enum DistributionDocumentationTests {
    private static let formulaInstall = "brew install ondrej-winter/tap/calrelay"
    private static let caskInstall = "brew install --cask ondrej-winter/tap/calrelay"

    static func runAll() throws {
        try testUserGuideDocumentsOnlySupportedInstallationSurface()
        try testOperatorRunbookDocumentsReleaseAndRecoveryProcedures()
        try testDistributionDocumentationIsLinkedFromProjectNavigation()
    }

    private static func testUserGuideDocumentsOnlySupportedInstallationSurface() throws {
        let guide = try contents(of: "docs/distribution.md")
        let normalizedGuide = normalizedWhitespace(guide)
        let installCommands = guide.split(separator: "\n").map(String.init).filter {
            $0.hasPrefix("brew install")
        }

        try expect(
            installCommands == [formulaInstall, caskInstall],
            "User distribution documentation must contain exactly the two fully qualified supported install commands")
        try expect(!guide.contains("brew tap "), "User documentation must not present an explicit tap command")
        try expect(
            !guide.contains("brew install calrelay"),
            "User documentation must not present a short formula command")
        try expect(
            !guide.contains("brew install --cask calrelay"), "User documentation must not present a short cask command")
        let claimsUnsupportedChannel = guide.contains("homebrew/core") || guide.contains("homebrew/cask")
            || guide.contains("official Homebrew")
        try expect(!claimsUnsupportedChannel, "User documentation must not claim unsupported Homebrew channels")
        for required in [
            "public channel is not live", "Apple Silicon", "macOS 26 or later", "CLI only", "App only",
            "Install both", "brew upgrade ondrej-winter/tap/calrelay",
            "brew upgrade --cask ondrej-winter/tap/calrelay", "brew uninstall ondrej-winter/tap/calrelay",
            "brew uninstall --cask ondrej-winter/tap/calrelay", "~/.config/calrelay/config.yaml",
            "ordinary uninstallation retains", "does not request Calendar permission", "Open `CalRelay.app` intentionally",
            "setup or recovery action", "no destructive `zap`",
        ] {
            try expect(normalizedGuide.contains(required), "User distribution documentation must contain \(required)")
        }
    }

    private static func testOperatorRunbookDocumentsReleaseAndRecoveryProcedures() throws {
        let runbook = try contents(of: "docs/release-operations.md")
        let normalizedRunbook = normalizedWhitespace(runbook)
        for required in [
            "public channel is not live", "gh workflow run release.yml -f bootstrap=true", "qualifying push to `master`",
            "CALRELAY_DEVELOPER_ID_P12", "CALRELAY_DEVELOPER_ID_P12_PASSWORD", "CALRELAY_NOTARY_API_KEY_P8",
            "CALRELAY_NOTARY_KEY_ID", "CALRELAY_NOTARY_ISSUER_ID", "CALRELAY_DEVELOPER_TEAM_ID",
            "CALRELAY_SIGNING_CERTIFICATE_SHA1", "Protected environment secret",
            "40-character SHA-1 certificate fingerprint",
            "CALRELAY_RELEASE_GITHUB_APP_PRIVATE_KEY",
            "CALRELAY_RELEASE_GITHUB_APP_ID", "CALRELAY_TAP_REPOSITORY",
            "`xcode-27`", "public preview", "fresh GitHub-hosted VM",
            "gh workflow run release.yml -f resume_run_id=123456789", "Do not rebuild the same version",
            "Do not move or replace same-version tags or assets", "higher patch version", "compromised artifact",
            "disable", "## Runner recovery", "## Tap recovery", "scripts/release/release-state.mjs",
        ] {
            try expect(normalizedRunbook.contains(required), "Release operator documentation must contain \(required)")
        }
    }

    private static func testDistributionDocumentationIsLinkedFromProjectNavigation() throws {
        let readme = try contents(of: "README.md")
        let development = try contents(of: "docs/development.md")
        let layout = try contents(of: "docs/repository-layout.md")

        for link in ["docs/distribution.md", "docs/release-operations.md"] {
            try expect(readme.contains(link), "README must link \(link)")
        }
        try expect(
            development.contains("[Release operations](release-operations.md)"),
            "Development documentation must link the release runbook")
        for page in ["docs/distribution.md", "docs/release-operations.md"] {
            try expect(layout.contains(page), "Repository layout must list \(page)")
        }
    }

    private static func contents(of relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func normalizedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
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

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}