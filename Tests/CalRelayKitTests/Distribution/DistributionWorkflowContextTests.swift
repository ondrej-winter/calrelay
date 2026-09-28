import Foundation

enum DistributionWorkflowContextTests {
    static func runAll() throws {
        try testCurrentWorkflowIdentityIsAccepted()
        try testHistoricalWorkflowIdentityIsAccepted()
        try testMismatchedWorkflowIdentityIsRejected()
        try testMismatchedSourceRevisionIsRejected()
        try testInvalidRetainedStateIsRejected()
    }

    private static func testCurrentWorkflowIdentityIsAccepted() throws {
        let fixture = try WorkflowContextFixture(
            workflowName: "CI/CD", workflowPath: ".github/workflows/ci-cd.yaml")
        defer { fixture.remove() }

        let result = try fixture.verify()

        try expect(result.status == 0, "Current CI/CD workflow identity must be accepted: \(result.output)")
        let output = try fixture.output()
        try expect(output["source_revision"] == fixture.sourceRevision, "The captured source revision must be emitted")
        try expect(
            output["validation_revision"] == fixture.releaseCommit,
            "The retained release commit must be selected for exact-revision validation")
        try expect(output["release_commit"] == fixture.releaseCommit, "The retained release commit must be emitted")
        try expect(output["tag"] == "v1.0.3", "The retained release tag must be emitted")
    }

    private static func testHistoricalWorkflowIdentityIsAccepted() throws {
        let fixture = try WorkflowContextFixture(
            workflowName: "Public-beta release", workflowPath: ".github/workflows/release.yml")
        defer { fixture.remove() }

        let result = try fixture.verify()

        try expect(result.status == 0, "Unexpired candidates from the historical workflow must remain resumable: \(result.output)")
    }

    private static func testMismatchedWorkflowIdentityIsRejected() throws {
        let fixture = try WorkflowContextFixture(
            workflowName: "Untrusted workflow", workflowPath: ".github/workflows/untrusted.yml")
        defer { fixture.remove() }

        let result = try fixture.verify()

        try expect(result.status != 0, "An arbitrary workflow identity must be rejected")
        try expect(result.output.contains("protected release workflow run"), "Workflow mismatch diagnostics must identify provenance")
    }

    private static func testMismatchedSourceRevisionIsRejected() throws {
        let fixture = try WorkflowContextFixture(
            workflowName: "CI/CD", workflowPath: ".github/workflows/ci-cd.yaml",
            runHeadSHA: String(repeating: "c", count: 40))
        defer { fixture.remove() }

        let result = try fixture.verify()

        try expect(result.status != 0, "A workflow run for another source revision must be rejected")
        try expect(result.output.contains("protected release workflow run"), "Revision mismatch diagnostics must identify provenance")
    }

    private static func testInvalidRetainedStateIsRejected() throws {
        let fixture = try WorkflowContextFixture(
            workflowName: "CI/CD", workflowPath: ".github/workflows/ci-cd.yaml", schemaVersion: 2)
        defer { fixture.remove() }

        let result = try fixture.verify()

        try expect(result.status != 0, "An unsupported retained-state schema must be rejected")
        try expect(result.output.contains("retained release source metadata"), "State diagnostics must identify retained metadata")
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(message) }
    }
}

private final class WorkflowContextFixture {
    let sourceRevision = String(repeating: "a", count: 40)
    let releaseCommit = String(repeating: "b", count: 40)
    private let root: URL
    private let state: URL
    private let run: URL
    private let outputFile: URL
    private let runID = "123456789"

    init(
        workflowName: String, workflowPath: String, runHeadSHA: String? = nil,
        schemaVersion: Int = 3
    ) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "calrelay-workflow-context-\(UUID().uuidString)")
        state = root.appendingPathComponent("release-state.json")
        run = root.appendingPathComponent("workflow-run.json")
        outputFile = root.appendingPathComponent("output.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try writeJSON(
            [
                "schemaVersion": schemaVersion,
                "version": "1.0.3",
                "tag": "v1.0.3",
                "sourceRevision": sourceRevision,
                "releaseCommit": releaseCommit,
            ], to: state)
        try writeJSON(
            [
                "id": Int(runID)!,
                "name": workflowName,
                "path": workflowPath,
                "event": "workflow_dispatch",
                "status": "completed",
                "head_branch": "master",
                "head_sha": runHeadSHA ?? sourceRevision,
                "repository": ["full_name": "ondrej-winter/calrelay"],
                "head_repository": ["full_name": "ondrej-winter/calrelay"],
            ], to: run)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func verify() throws -> WorkflowContextProcessResult {
        let repositoryRoot = try DistributionReleaseWorkflowTests.repositoryRoot()
        return try command(
            "/usr/bin/env",
            [
                "node", repositoryRoot.appendingPathComponent("scripts/release/verify-resume-workflow.mjs").path,
                "--state", state.path,
                "--run", run.path,
                "--repository", "ondrej-winter/calrelay",
                "--run-id", runID,
                "--output", outputFile.path,
            ], at: root)
    }

    func output() throws -> [String: String] {
        let contents = try String(contentsOf: outputFile, encoding: .utf8)
        return Dictionary(uniqueKeysWithValues: contents.split(separator: "\n").map { line in
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]), String(parts[1]))
        })
    }

    private func writeJSON(_ value: [String: Any], to path: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: path)
    }

    private func command(_ executable: String, _ arguments: [String], at directory: URL) throws -> WorkflowContextProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return WorkflowContextProcessResult(status: process.terminationStatus, output: output)
    }
}

private struct WorkflowContextProcessResult {
    let status: Int32
    let output: String
}