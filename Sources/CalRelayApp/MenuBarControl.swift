import AppKit
import SwiftUI

struct MenuBarControl: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open CalRelay") {
            NSApp.activate()
            openWindow(id: "main")
        }

        Divider()

        Button("Quit") { NSApp.terminate(nil) }
    }
}
