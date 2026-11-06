import AppKit
import Combine

@MainActor final class CalendarMenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let viewModel: CalendarListViewModel
    private let openControlPanel: () -> Void
    private let primaryStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let schedulingStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var observation: AnyCancellable?

    init(viewModel: CalendarListViewModel, openControlPanel: @escaping () -> Void) {
        self.viewModel = viewModel
        self.openControlPanel = openControlPanel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.autosaveName = "CalRelay"
        statusItem.behavior = [.removalAllowed]
        statusItem.button?.setAccessibilityIdentifier("calrelay-status-item")
        let menu = NSMenu()
        menu.addItem(primaryStatus)
        menu.addItem(schedulingStatus)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open CalRelay", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit CalRelay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        updatePresentation()
        observation = viewModel.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.updatePresentation() }
        }
    }

    private func updatePresentation() {
        let text: String
        let symbol: String
        switch viewModel.statusRefreshState {
        case .notChecked, .checking:
            text = "CalRelay status has not been checked."
            symbol = "questionmark.circle"
        case .failed:
            text = "Status refresh failed. Open CalRelay to recover."
            symbol = "exclamationmark.circle"
        case .checked:
            text = viewModel.isLoading ? "CalRelay is working…" : viewModel.primaryStatus
            if viewModel.automationAttentionReason != nil {
                symbol = "exclamationmark.circle"
            } else {
                symbol = viewModel.isSchedulingEnabled ? "calendar" : "pause.circle"
            }
        }
        primaryStatus.title = text
        schedulingStatus.title = viewModel.schedulingSummary
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        statusItem.button?.setAccessibilityLabel("CalRelay: \(text) \(viewModel.notificationSummary)")
        statusItem.button?.toolTip = "\(text)\n\(viewModel.schedulingSummary)"
    }

    @objc private func openPanel() { openControlPanel() }
}
