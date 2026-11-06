import AppKit

@MainActor final class CalendarMenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let openControlPanel: () -> Void

    init(openControlPanel: @escaping () -> Void) {
        self.openControlPanel = openControlPanel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.autosaveName = "CalRelay"
        statusItem.behavior = [.removalAllowed]
        statusItem.button?.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "CalRelay")
        statusItem.button?.setAccessibilityLabel("CalRelay")
        statusItem.button?.setAccessibilityIdentifier("calrelay-status-item")
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open CalRelay", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit CalRelay", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func openPanel() { openControlPanel() }
}
