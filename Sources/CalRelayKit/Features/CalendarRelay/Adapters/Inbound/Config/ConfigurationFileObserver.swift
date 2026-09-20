import Darwin
import Dispatch
import Foundation

public final class ConfigurationFileObserver: @unchecked Sendable {
    private let selectedFile: SelectedConfigurationFile
    private let isEnabled: Bool
    private let queue = DispatchQueue(label: "dev.owinter.CalRelay.configuration-observer")
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var observedDirectoryPath: String?
    private var lastFingerprint: FileFingerprint?
    private var onChange: (@Sendable () -> Void)?

    public init(selectedFile: SelectedConfigurationFile, isEnabled: Bool = true) {
        self.selectedFile = selectedFile
        self.isEnabled = isEnabled
    }

    deinit { stop() }

    public func start(onChange: @escaping @Sendable () -> Void) {
        guard isEnabled else { return }
        queue.sync { [self] in
            self.onChange = onChange
            lastFingerprint = fingerprint()
            installSource()
            installTimer()
        }
    }

    public func stop() {
        queue.sync { [self] in
            onChange = nil
            observedDirectoryPath = nil
            source?.cancel()
            source = nil
            timer?.cancel()
            timer = nil
        }
    }

    private func installSource() {
        let directoryPath = nearestExistingDirectoryPath()
        guard directoryPath != observedDirectoryPath else { return }

        source?.cancel()
        source = nil
        observedDirectoryPath = directoryPath

        let descriptor = open(directoryPath, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
            queue: queue)
        source.setEventHandler { [weak self] in self?.directoryDidChange() }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    private func installTimer() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.checkForChange() }
        self.timer = timer
        timer.resume()
    }

    private func directoryDidChange() { checkForChange() }

    private func checkForChange() {
        let currentFingerprint = fingerprint()
        guard currentFingerprint != lastFingerprint else { return }
        lastFingerprint = currentFingerprint
        installSource()
        onChange?()
    }

    private func nearestExistingDirectoryPath() -> String {
        var candidate = URL(fileURLWithPath: selectedFile.path).deletingLastPathComponent()
        var isDirectory: ObjCBool = false

        while !FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
            || !isDirectory.boolValue
        {
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { return parent.path }
            candidate = parent
            isDirectory = false
        }

        return candidate.path
    }

    private func fingerprint() -> FileFingerprint? {
        var details = stat()
        guard lstat(selectedFile.path, &details) == 0 else { return nil }
        return FileFingerprint(
            device: UInt64(details.st_dev), inode: UInt64(details.st_ino), size: Int64(details.st_size),
            modifiedSeconds: Int64(details.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(details.st_mtimespec.tv_nsec))
    }
}

private struct FileFingerprint: Equatable {
    let device: UInt64
    let inode: UInt64
    let size: Int64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
}
