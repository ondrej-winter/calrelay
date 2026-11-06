import AppKit
import CalRelayKit
import CoreServices
import SwiftUI

@MainActor final class CalRelayAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private(set) var initialLaunchContext = CalendarAppLaunchContext.ordinary
    private var isAwaitingLoginPresentation = false
    private var viewModel: CalendarListViewModel?
    private var controlPanel: NSWindow?
    private var menuBar: CalendarMenuBarController?
    private var didInjectUITestProblem = false

    var runtimeAlertsEnabled: Bool { viewModel?.didResolveInitialLaunchPresentation == true }

    func configure(viewModel: CalendarListViewModel) { self.viewModel = viewModel }

    func applicationWillFinishLaunching(_ notification: Notification) {
        if CalendarUITestScenario.current(arguments: CommandLine.arguments) == .healthyLogin {
            initialLaunchContext = .loginItem
        } else {
            initialLaunchContext = Self.launchContext(for: NSAppleEventManager.shared().currentAppleEvent)
        }
        isAwaitingLoginPresentation = initialLaunchContext == .loginItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let viewModel else { return }
        menuBar = CalendarMenuBarController(
            viewModel: viewModel, openControlPanel: { [weak self] in self?.openControlPanel() })
        if !isAwaitingLoginPresentation { showControlPanel() }
        viewModel.start()
    }

    func resolveInitialLaunchPresentation(_ presentation: CalendarLoginLaunchPresentation) {
        guard isAwaitingLoginPresentation else { return }
        isAwaitingLoginPresentation = false
        if presentation == .showControlPanel { showControlPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openControlPanel()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard !didInjectUITestProblem, let viewModel, notification.object as? NSWindow === controlPanel else { return }
        didInjectUITestProblem = true
        CalendarUITestComposition.handleWindowClosure(viewModel: viewModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard viewModel?.isSchedulingEnabled == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quit CalRelay?"
        alert.informativeText =
            "Scheduled synchronization stops when CalRelay is not running. Availability may become stale until the next manual launch or login."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func openControlPanel() {
        isAwaitingLoginPresentation = false
        showControlPanel()
    }

    private func showControlPanel() {
        guard let viewModel else { return }
        if controlPanel == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 860),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "CalRelay"
            window.identifier = NSUserInterfaceItemIdentifier("calrelay-control-panel")
            window.minSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: CalendarListView(viewModel: viewModel))
            window.center()
            controlPanel = window
        }
        controlPanel?.deminiaturize(nil)
        controlPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private static func launchContext(for event: NSAppleEventDescriptor?) -> CalendarAppLaunchContext {
        guard event?.eventID == kAEOpenApplication,
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        else { return .ordinary }
        return .loginItem
    }
}
