import Foundation

// ACCESS-AC-01: production prompt metadata is required while the fake UI-test host stays permission-free.
enum CalendarAppBundleMetadataTests {
    private static let calendarUsageDescriptionKeys = [
        "NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription"
    ]

    static func runAll() throws {
        try testProductionSourceInfoPlistContainsNonemptyCalendarUsageDescriptions()
        try testUITestHostSourceInfoPlistOmitsCalendarUsageDescriptions()
        try testAppBuildRejectsMissingCalendarUsageDescriptions()
        try testAppBuildRejectsEmptyCalendarUsageDescriptions()
    }

    private static func testProductionSourceInfoPlistContainsNonemptyCalendarUsageDescriptions() throws {
        let metadata = try propertyList(
            at: try repositoryRoot().appendingPathComponent("Resources/CalRelayApp/Info.plist"))

        for key in calendarUsageDescriptionKeys { try expectNonemptyString(metadata[key], key: key) }
    }

    private static func testUITestHostSourceInfoPlistOmitsCalendarUsageDescriptions() throws {
        let metadata = try propertyList(
            at: try repositoryRoot().appendingPathComponent("Resources/CalRelayUITestHost/Info.plist"))

        for key in calendarUsageDescriptionKeys {
            try expect(metadata[key] == nil, "The fake UI-test host must not declare \(key)")
        }
    }

    private static func testAppBuildRejectsMissingCalendarUsageDescriptions() throws {
        for key in calendarUsageDescriptionKeys {
            try expectAppBuildRejects(calendarUsageDescription: key, replacement: nil)
        }
    }

    private static func testAppBuildRejectsEmptyCalendarUsageDescriptions() throws {
        for key in calendarUsageDescriptionKeys {
            try expectAppBuildRejects(calendarUsageDescription: key, replacement: "   \n")
        }
    }

    private static func expectAppBuildRejects(calendarUsageDescription key: String, replacement: String?) throws {
        let fileManager = FileManager.default
        let root = try repositoryRoot()
        let fixtureRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "CalendarAppBundleMetadataTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        let directories = [
            fixtureRoot.appendingPathComponent("scripts", isDirectory: true),
            fixtureRoot.appendingPathComponent("Resources/CalRelayApp", isDirectory: true),
            fixtureRoot.appendingPathComponent(".build/debug", isDirectory: true),
            fixtureRoot.appendingPathComponent("bin", isDirectory: true),
            fixtureRoot.appendingPathComponent("home", isDirectory: true)
        ]
        for directory in directories {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let script = fixtureRoot.appendingPathComponent("scripts/build-calrelay-app.sh")
        try fileManager.copyItem(at: root.appendingPathComponent("scripts/build-calrelay-app.sh"), to: script)

        var metadata = try propertyList(at: root.appendingPathComponent("Resources/CalRelayApp/Info.plist"))
        if let replacement { metadata[key] = replacement } else { metadata.removeValue(forKey: key) }
        try expectInvalidCalendarUsageDescription(metadata[key], key: key)
        let metadataData = try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
        let fixtureInfoPlist = fixtureRoot.appendingPathComponent("Resources/CalRelayApp/Info.plist")
        try metadataData.write(to: fixtureInfoPlist)
        try expectInvalidCalendarUsageDescription(try propertyList(at: fixtureInfoPlist)[key], key: key)

        try writeExecutable(
            at: fixtureRoot.appendingPathComponent(".build/debug/CalRelayApp"), contents: "#!/bin/zsh\nexit 0\n")
        try writeExecutable(at: fixtureRoot.appendingPathComponent("bin/swift"), contents: "#!/bin/zsh\nexit 0\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [script.path]
        process.currentDirectoryURL = fixtureRoot
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = fixtureRoot.appendingPathComponent("home").path
        environment["PATH"] =
            fixtureRoot.appendingPathComponent("bin").path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        try expect(
            process.terminationStatus != 0,
            "App build must fail for invalid \(key); status=\(process.terminationStatus), output=\(output)")
        try expect(output.contains(key), "App build failure must identify \(key)")
        try expect(
            output.contains("must be a nonempty string"),
            "App build failure must explain the nonempty string requirement")
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

    private static func propertyList(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let metadata = propertyList as? [String: Any] else {
            throw TestFailure("Expected a dictionary property list at \(url.path)")
        }
        return metadata
    }

    private static func writeExecutable(at url: URL, contents: String) throws {
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private static func expectInvalidCalendarUsageDescription(_ value: Any?, key: String) throws {
        if let string = value as? String {
            try expect(
                string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Test fixture must make \(key) empty")
        } else {
            try expect(value == nil, "Test fixture must remove \(key) or make it empty")
        }
    }

    private static func expectNonemptyString(_ value: Any?, key: String) throws {
        guard let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TestFailure("\(key) must be a nonempty string")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message) }
    }
}
