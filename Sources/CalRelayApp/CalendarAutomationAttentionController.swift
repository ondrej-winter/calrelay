import AppKit
import CalRelayKit
import UserNotifications

@MainActor protocol CalendarAutomationAttentionControlling: AnyObject {
    func requestAuthorization() async
    func authorizationSummary() async -> String
    func update(reason: CalendarAutomationAttentionReason?)
}

@MainActor final class CalendarAutomationAttentionController: NSObject, CalendarAutomationAttentionControlling,
    UNUserNotificationCenterDelegate
{
    private static let notificationIdentifier = "calendar-automation-attention"
    private let center: UNUserNotificationCenter?
    private var currentReason: CalendarAutomationAttentionReason?

    init(isEnabled: Bool = true) {
        center = isEnabled ? UNUserNotificationCenter.current() : nil
        super.init()
        center?.delegate = self
    }

    func requestAuthorization() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge])
    }

    func authorizationSummary() async -> String {
        guard let center else { return "Disabled in the isolated UI-test host." }
        return switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: "Not requested. In-app and Dock fallback state remains active."
        case .denied: "Denied. Scheduling remains available with in-app and Dock fallback state."
        case .authorized: "Authorized for actionable recovery and overdue-freshness alerts."
        case .provisional: "Provisionally authorized for recovery and overdue-freshness alerts."
        @unknown default: "Unavailable. In-app and Dock fallback state remains active."
        }
    }

    func update(reason: CalendarAutomationAttentionReason?) {
        let changed = reason != currentReason
        currentReason = reason
        guard let center else { return }
        NSApp.dockTile.badgeLabel = reason == nil ? nil : "!"
        NSApp.dockTile.display()

        guard let reason else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
            return
        }
        guard changed, reason != .schedulingPaused else { return }
        Task { await deliverIfAuthorized(reason) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func deliverIfAuthorized(_ reason: CalendarAutomationAttentionReason) async {
        guard let center else { return }
        let authorization = await center.notificationSettings().authorizationStatus
        guard authorization == .authorized || authorization == .provisional else { return }

        let notification = CalendarAutomationAttentionNotification(reason: reason)
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier, content: content, trigger: nil)
        try? await center.add(request)
    }
}