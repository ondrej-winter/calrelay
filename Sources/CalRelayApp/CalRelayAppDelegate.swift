import AppKit
import CalRelayKit
import CoreServices
import SwiftUI

@MainActor final class CalRelayAppDelegate: NSObject, NSApplicationDelegate {
    var shouldWarnBeforeQuit: () -> Bool = { false }
    private(set) var initialLaunchContext = CalendarAppLaunchContext.ordinary
    private var isSuppressingInitialLoginWindow = false
    private var windowPresentationObserver: NSObjectProtocol?
    private var uiTestViewModel: CalendarListViewModel?
    private var uiTestWindow: NSWindow?

    func configureUITestWindow(viewModel: CalendarListViewModel) { uiTestViewModel = viewModel }

    func applicationWillFinishLaunching(_ notification: Notification) {
        initialLaunchContext = Self.launchContext(for: NSAppleEventManager.shared().currentAppleEvent)
        guard initialLaunchContext == .loginItem else { return }

        isSuppressingInitialLoginWindow = true
        windowPresentationObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.hideControlPanel() } }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let uiTestViewModel {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 860),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "CalRelay"
            window.center()
            window.contentView = NSHostingView(rootView: CalendarListView(viewModel: uiTestViewModel))
            window.makeKeyAndOrderFront(nil)
            uiTestWindow = window
            NSApp.activate()
            return
        }
        if isSuppressingInitialLoginWindow { hideControlPanel() }
    }

    func resolveInitialLaunchPresentation(_ presentation: CalendarLoginLaunchPresentation) {
        guard isSuppressingInitialLoginWindow else { return }
        switch presentation {
        case .showControlPanel:
            stopSuppressingInitialLoginWindow()
            showControlPanel()
        case .keepControlPanelHidden:
            hideControlPanel()
            stopSuppressingInitialLoginWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        stopSuppressingInitialLoginWindow()
        showControlPanel()
        return false
    }

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

    private static func launchContext(for event: NSAppleEventDescriptor?) -> CalendarAppLaunchContext {
        guard event?.eventID == kAEOpenApplication,
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        else { return .ordinary }
        return .loginItem
    }

    private func stopSuppressingInitialLoginWindow() {
        isSuppressingInitialLoginWindow = false
        if let windowPresentationObserver { NotificationCenter.default.removeObserver(windowPresentationObserver) }
        windowPresentationObserver = nil
    }

    private func hideControlPanel() {
        guard isSuppressingInitialLoginWindow else { return }
        for window in NSApp.windows { window.orderOut(nil) }
    }

    private func showControlPanel() {
        NSApp.activate()
        for window in NSApp.windows { window.makeKeyAndOrderFront(nil) }
    }
}
