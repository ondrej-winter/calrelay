import Foundation

enum DistributionVersionTests {
    static func runAll() throws {
        try testRootVersionIsCanonical()
        try testGeneratedCLIVersionMatchesRootVersion()
        try testPackageUsesRequiredSwiftToolsAndDeploymentTarget()
        try testAppBuildDerivesBothVersionsFromRootVersion()
        try testAppBuildRejectsMalformedVersions()
        try testAppBuildPreservesProductionIdentity()
        try testAppBuildCopiesApplicationIcon()
    }

    private static func testRootVersionIsCanonical() throws {
        let data = try Data(contentsOf: repositoryRoot().appendingPathComponent("VERSION"))
        guard let contents = String(data: data, encoding: .utf8) else {
            throw TestFailure("VERSION must contain UTF-8 text")
        }

        let pattern = #"\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\z"#
        try expect(
            contents.range(of: pattern, options: .regularExpression) != nil,
            "VERSION must contain exactly one canonical X.Y.Z value without surrounding content")
    }

    private static func testGeneratedCLIVersionMatchesRootVersion() throws {
        let root = try repositoryRoot()
        let version = try rootVersion(at: root)
        let generated = try String(
            contentsOf: root.appendingPathComponent("Sources/CalRelayCLI/GeneratedReleaseVersion.swift"), encoding: .utf8)

        try expect(
            generated.contains("static let value = \"\(version)\""),
            "The generated CLI release version must match VERSION")
    }

    private static func testPackageUsesRequiredSwiftToolsAndDeploymentTarget() throws {
        let package = try String(contentsOf: repositoryRoot().appendingPathComponent("Package.swift"), encoding: .utf8)

        try expect(package.hasPrefix("// swift-tools-version: 6.4\n"), "Package.swift must require Swift tools 6.4")
        try expect(package.contains("platforms: [.macOS(.v26)]"), "Package.swift must retain macOS 26 as the minimum")
    }

    private static func testAppBuildDerivesBothVersionsFromRootVersion() throws {
        let first = try AppBuildFixture(version: "2.9.9").buildMetadata()
        let second = try AppBuildFixture(version: "2.10.0").buildMetadata()

        try expect(first["CFBundleShortVersionString"] as? String == "2.9.9", "App short version must derive from VERSION")
        try expect(first["CFBundleVersion"] as? String == "2.9.9", "App bundle version must derive from VERSION")
        try expect(second["CFBundleShortVersionString"] as? String == "2.10.0", "Later app short version must derive from VERSION")
        try expect(second["CFBundleVersion"] as? String == "2.10.0", "Later app bundle version must derive from VERSION")
        try expect(
            compareVersion("2.9.9", isLessThan: "2.10.0"),
            "The bundle-version mapping must increase for later semantic versions")
    }

    private static func testAppBuildRejectsMalformedVersions() throws {
        for malformed in ["v1.2.3", "01.2.3", "1.2.3\n", "1.2.3\nextra", "1.2", "1.2.3-beta"] {
            let result = try AppBuildFixture(version: malformed).build()
            try expect(result.status != 0, "App build must reject malformed VERSION value \(malformed.debugDescription)")
            try expect(result.output.contains("VERSION"), "Malformed version failure must identify VERSION")
            try expect(result.output.contains("canonical X.Y.Z"), "Malformed version failure must explain the format")
        }
    }

    private static func testAppBuildPreservesProductionIdentity() throws {
        let metadata = try AppBuildFixture(version: "3.4.5").buildMetadata()

        try expect(metadata["CFBundleName"] as? String == "CalRelay", "App name must remain CalRelay")
        try expect(metadata["CFBundleExecutable"] as? String == "CalRelayApp", "App executable must remain CalRelayApp")
        try expect(
            metadata["CFBundleIdentifier"] as? String == "dev.owinter.CalRelay",
            "App bundle identifier must remain dev.owinter.CalRelay")
        try expect(metadata["LSMinimumSystemVersion"] as? String == "26.0", "App minimum system version must remain 26.0")
    }

    private static func testAppBuildCopiesApplicationIcon() throws {
        let root = try repositoryRoot()
        let sourceIcon = try Data(contentsOf: root.appendingPathComponent("Resources/CalRelayApp/CalRelay.icns"))
        let bundledIcon = try AppBuildFixture(version: "3.4.5").buildApplicationIcon()

        try expect(bundledIcon == sourceIcon, "The local app bundle must contain the source CalRelay.icns application icon")
    }

    private static func compareVersion(_ first: String, isLessThan second: String) -> Bool {
        let firstParts = first.split(separator: ".").compactMap { Int($0) }
        let secondParts = second.split(separator: ".").compactMap { Int($0) }
        return firstParts.lexicographicallyPrecedes(secondParts)
    }

    private static func rootVersion(at root: URL) throws -> String {
        try String(contentsOf: root.appendingPathComponent("VERSION"), encoding: .utf8)
            .trimmingCharacters(in: .newlines)
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

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}

private struct AppBuildFixture {
    let root: URL

    init(version: String) throws {
        let fileManager = FileManager.default
        root = fileManager.temporaryDirectory.appendingPathComponent(
            "DistributionVersionTests-\(UUID().uuidString)", isDirectory: true)

        for directory in [
            root.appendingPathComponent("scripts", isDirectory: true),
            root.appendingPathComponent("Resources/CalRelayApp", isDirectory: true),
            root.appendingPathComponent(".build/debug", isDirectory: true),
            root.appendingPathComponent("bin", isDirectory: true),
            root.appendingPathComponent("home", isDirectory: true)
        ] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let repository = try Self.repositoryRoot()
        try fileManager.copyItem(
            at: repository.appendingPathComponent("scripts/build-calrelay-app.sh"),
            to: root.appendingPathComponent("scripts/build-calrelay-app.sh"))
        try fileManager.copyItem(
            at: repository.appendingPathComponent("Resources/CalRelayApp/Info.plist"),
            to: root.appendingPathComponent("Resources/CalRelayApp/Info.plist"))
        try fileManager.copyItem(
            at: repository.appendingPathComponent("Resources/CalRelayApp/CalRelayApp.entitlements"),
            to: root.appendingPathComponent("Resources/CalRelayApp/CalRelayApp.entitlements"))
        try fileManager.copyItem(
            at: repository.appendingPathComponent("Resources/CalRelayApp/CalRelay.icns"),
            to: root.appendingPathComponent("Resources/CalRelayApp/CalRelay.icns"))
        try Data(version.utf8).write(to: root.appendingPathComponent("VERSION"))
        let appExecutable = root.appendingPathComponent(".build/debug/CalRelayApp")
        try fileManager.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: appExecutable)
        try writeExecutable(at: root.appendingPathComponent("bin/swift"), contents: "#!/bin/zsh\nexit 0\n")
    }

    func buildMetadata() throws -> [String: Any] {
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try runBuild()
        try expect(result.status == 0, "Fixture app build must succeed: \(result.output)")

        let infoPlist = try appBundle().appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoPlist)
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let metadata = propertyList as? [String: Any] else {
            throw TestFailure("Expected a dictionary property list at \(infoPlist.path)")
        }
        return metadata
    }

    func buildApplicationIcon() throws -> Data {
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try runBuild()
        try expect(result.status == 0, "Fixture app build must succeed: \(result.output)")
        return try Data(contentsOf: try appBundle().appendingPathComponent("Contents/Resources/CalRelay.icns"))
    }

    func build() throws -> AppBuildResult {
        defer { try? FileManager.default.removeItem(at: root) }
        return try runBuild()
    }

    private func runBuild() throws -> AppBuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [root.appendingPathComponent("scripts/build-calrelay-app.sh").path]
        process.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = root.appendingPathComponent("home").path
        environment["PATH"] = root.appendingPathComponent("bin").path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return AppBuildResult(status: process.terminationStatus, output: output)
    }

    private func appBundle() throws -> URL {
        let builds = root.appendingPathComponent("home/Library/Caches/dev.owinter.CalRelay/builds")
        let workspaceDirectories = try FileManager.default.contentsOfDirectory(
            at: builds, includingPropertiesForKeys: nil)
        guard let workspace = workspaceDirectories.first else {
            throw TestFailure("Fixture app build did not create a workspace directory")
        }
        return workspace.appendingPathComponent("CalRelay.app")
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

    private func writeExecutable(at url: URL, contents: String) throws {
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}

private struct AppBuildResult {
    let status: Int32
    let output: String
}