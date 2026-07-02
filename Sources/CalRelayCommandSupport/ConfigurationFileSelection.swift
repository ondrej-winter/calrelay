import Foundation

public enum ConfigurationFileSource: Equatable, Sendable {
    case defaultPath
    case explicitOverride
}

public struct SelectedConfigurationFile: Equatable, Sendable {
    public let path: String
    public let displayPath: String
    public let source: ConfigurationFileSource

    public init(path: String, displayPath: String, source: ConfigurationFileSource) {
        self.path = path
        self.displayPath = displayPath
        self.source = source
    }
}

public struct MissingConfigurationFileError: Error, CustomStringConvertible, LocalizedError, Equatable, Sendable {
    public let selectedFile: SelectedConfigurationFile

    public init(selectedFile: SelectedConfigurationFile) { self.selectedFile = selectedFile }

    public var description: String { message }

    public var errorDescription: String? { message }

    private var message: String {
        switch selectedFile.source {
        case .defaultPath:
            """
            No CalRelay configuration file found at \(selectedFile.displayPath).
            Create one there or pass --config <path>.
            See docs/configuration.md for an example.
            """
        case .explicitOverride:
            """
            No CalRelay configuration file found at \(selectedFile.displayPath).
            Check the path or pass a different --config <path>.
            """
        }
    }
}

public enum ConfigurationFileSelection {
    public static let defaultRelativePath = ".config/calrelay/config.yaml"
    public static let defaultDisplayPath = "~/.config/calrelay/config.yaml"

    public static func select(
        overridePath: String?, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) throws -> SelectedConfigurationFile {
        let selectedFile = selectedFile(overridePath: overridePath, homeDirectory: homeDirectory)

        guard fileExists(selectedFile.path) else { throw MissingConfigurationFileError(selectedFile: selectedFile) }

        return selectedFile
    }

    public static func selectedFile(
        overridePath: String?, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SelectedConfigurationFile {
        if let overridePath, !overridePath.isEmpty {
            return SelectedConfigurationFile(path: overridePath, displayPath: overridePath, source: .explicitOverride)
        }

        let path = homeDirectory.appendingPathComponent(defaultRelativePath).path
        return SelectedConfigurationFile(path: path, displayPath: defaultDisplayPath, source: .defaultPath)
    }
}
