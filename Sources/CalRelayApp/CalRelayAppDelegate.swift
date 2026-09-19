import AppKit

@MainActor final class CalRelayAppDelegate: NSObject, NSApplicationDelegate {
    var shouldWarnBeforeQuit: () -> Bool = { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard shouldWarnBeforeQuit() else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit CalRelay?"
        alert.informativeText =
            "Scheduled synchronization stops when the normal app is not running. Availability may become stale until the next manual launch or login."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}