import Foundation

@main
struct CalRelayKitTestRunner {
    static func main() async throws {
        let filters = Set(CommandLine.arguments.dropFirst())

        if filters.isEmpty || filters.contains("ConfigurationFileSelectionTests") {
            try ConfigurationFileSelectionTests.runAll()
        }

        if filters.isEmpty || filters.contains("CalRelayContractTests") {
            try await CalRelayContractTests.runAll()
        }

        print("CalRelayKitTests passed")
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}