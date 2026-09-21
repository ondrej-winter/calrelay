import CalRelayKit
import Foundation

enum FileCalendarRelaySettingsProviderTests {
    static func runAll() async throws {
        try await testMissingSelectedFileCreatesNothingAndSearchesNowhereElse()
        try await testUnreadableAndNonUTF8SelectedFilesAreInvalid()
        try await testStructurallyInvalidFileIsPrivacySafe()
        try await testEveryCallReloadsTheSelectedPath()
    }

    private static func testMissingSelectedFileCreatesNothingAndSearchesNowhereElse() async throws {
        let fixture = try ProviderFileFixture(createSelectedParent: false)
        defer { fixture.cleanup() }
        let alternateFile = fixture.rootURL.appendingPathComponent("alternate.yaml")
        try Data(validYAML(personalMarker: "[ALTERNATE]").utf8).write(to: alternateFile)
        let provider = FileCalendarRelaySettingsProvider(selectedFile: fixture.selectedFile)

        try await expectProviderError(
            provider, equals: .missing(displayPath: fixture.selectedFile.displayPath),
            "Missing selected path should return a typed missing result")

        try expect(
            !FileManager.default.fileExists(atPath: fixture.fileURL.deletingLastPathComponent().path),
            "Loading a missing configuration should not create its parent directory")
        try expect(
            FileManager.default.fileExists(atPath: alternateFile.path),
            "Loading a missing configuration should not modify an alternate file")
    }

    private static func testUnreadableAndNonUTF8SelectedFilesAreInvalid() async throws {
        let unreadableFixture = try ProviderFileFixture()
        defer { unreadableFixture.cleanup() }
        try FileManager.default.createDirectory(at: unreadableFixture.fileURL, withIntermediateDirectories: false)
        try await expectProviderError(
            FileCalendarRelaySettingsProvider(selectedFile: unreadableFixture.selectedFile),
            equals: .invalid(displayPath: unreadableFixture.selectedFile.displayPath),
            "A selected path that cannot be read as a file should be invalid")

        let nonUTF8Fixture = try ProviderFileFixture()
        defer { nonUTF8Fixture.cleanup() }
        try Data([0xFF, 0xFE, 0xFD]).write(to: nonUTF8Fixture.fileURL)
        try await expectProviderError(
            FileCalendarRelaySettingsProvider(selectedFile: nonUTF8Fixture.selectedFile),
            equals: .invalid(displayPath: nonUTF8Fixture.selectedFile.displayPath),
            "A non-UTF-8 selected file should be invalid")
    }

    private static func testStructurallyInvalidFileIsPrivacySafe() async throws {
        let fixture = try ProviderFileFixture()
        defer { fixture.cleanup() }
        let privateValue = "PRIVATE_RAW_CONFIGURATION_SECRET"
        try fixture.write("unknownField: " + privateValue)
        let provider = FileCalendarRelaySettingsProvider(selectedFile: fixture.selectedFile)

        do { _ = try await provider.loadSettings() } catch let error as CalendarRelaySettingsProviderError {
            try expect(
                error == .invalid(displayPath: fixture.selectedFile.displayPath),
                "Structurally invalid YAML should return the normalized invalid result")
            try expect(
                !String(describing: error).contains(privateValue),
                "Invalid provider results should not reveal raw configuration content")
            return
        } catch { throw TestFailure("Structurally invalid YAML returned an unexpected error type") }
        throw TestFailure("Structurally invalid YAML should fail")
    }

    private static func testEveryCallReloadsTheSelectedPath() async throws {
        let fixture = try ProviderFileFixture()
        defer { fixture.cleanup() }
        let provider = FileCalendarRelaySettingsProvider(selectedFile: fixture.selectedFile)

        try fixture.write(validYAML(personalMarker: "[FIRST]"))
        let first = try await provider.loadSettings()
        try expect(first.settings.personalPrefix == "[FIRST]", "The first load should return the first file contents")

        try fixture.write(validYAML(personalMarker: "[SECOND]", legacyMarkers: ["[OLD]"]))
        let migrationPending = try await provider.loadSettings()
        try expect(
            migrationPending.settings.personalPrefix == "[SECOND]"
                && migrationPending.settings.legacyMarkers == ["[OLD]"],
            "A replacement should return its current migration-pending settings")

        try FileManager.default.removeItem(at: fixture.fileURL)
        try await expectProviderError(
            provider, equals: .missing(displayPath: fixture.selectedFile.displayPath),
            "Removing the selected file should not return last-known-valid settings")

        try fixture.write("personalPrefix: PRIVATE_INVALID_REPLACEMENT")
        try await expectProviderError(
            provider, equals: .invalid(displayPath: fixture.selectedFile.displayPath),
            "An invalid replacement should not return last-known-valid settings")

        try fixture.write(validYAML(personalMarker: "[THIRD]"))
        let recovered = try await provider.loadSettings()
        try expect(recovered.settings.personalPrefix == "[THIRD]", "A later valid replacement should be loaded afresh")
        try expect(
            recovered.displayPath == fixture.selectedFile.displayPath,
            "Every successful load should preserve the selected display path")
    }

    private static func expectProviderError(
        _ provider: FileCalendarRelaySettingsProvider, equals expected: CalendarRelaySettingsProviderError,
        _ message: String
    ) async throws {
        do { _ = try await provider.loadSettings() } catch let error as CalendarRelaySettingsProviderError {
            try expect(error == expected, message)
            return
        } catch { throw TestFailure(message + ": unexpected error type") }
        throw TestFailure(message + ": expected an error")
    }

    private static func validYAML(personalMarker: String, legacyMarkers: [String] = []) -> String {
        var lines = [
            "hubCalendar:", "  sourceTitle: Test Hub Source", "  calendarTitle: Test Hub",
            "personalPrefix: \"" + personalMarker + "\"", "syncWindowDays: 20", "workCalendars:",
            "  - name: Test Work Role", "    prefix: \"[WORK]\"", "    calendar:",
            "      sourceTitle: Test Work Source", "      calendarTitle: Test Work"
        ]
        if legacyMarkers.isEmpty {
            lines.append("legacyMarkers: []")
        } else {
            lines.append("legacyMarkers:")
            lines.append(contentsOf: legacyMarkers.map { "  - \"" + $0 + "\"" })
        }
        return lines.joined(separator: "\n")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct ProviderFileFixture {
    let rootURL: URL
    let fileURL: URL
    let selectedFile: SelectedConfigurationFile

    init(createSelectedParent: Bool = true) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        fileURL = rootURL.appendingPathComponent("selected/config.yaml")
        if createSelectedParent {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        selectedFile = SelectedConfigurationFile(
            path: fileURL.path, displayPath: "test-config.yaml", source: .explicitOverride)
    }

    func write(_ contents: String) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: fileURL, options: .atomic)
    }

    func cleanup() { try? FileManager.default.removeItem(at: rootURL) }
}
