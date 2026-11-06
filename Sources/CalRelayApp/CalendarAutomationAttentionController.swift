import AppKit
import CalRelayKit
import UserNotifications

@MainActor protocol CalendarAutomationAttentionControlling: AnyObject {
    func requestAuthorization() async
    func authorizationSummary() async -> String
    func update(reason: CalendarAutomationAttentionReason?)
}

@MainActor protocol CalendarAutomationNotificationDelivering: CalendarAutomationAlertPort {
    func requestAuthorization() async
    func authorizationSummary() async -> String
}

@MainActor final class CalendarAutomationAttentionController: CalendarAutomationAttentionControlling {
    private let delivery: any CalendarAutomationNotificationDelivering
    private let alerts: CalendarAutomationAlertUseCase
    private let runtimeAlertsEnabled: () -> Bool
    private var updateSequence: UInt = 0

    init(delivery: any CalendarAutomationNotificationDelivering, runtimeAlertsEnabled: @escaping () -> Bool) {
        self.delivery = delivery
        alerts = CalendarAutomationAlertUseCase(port: delivery)
        self.runtimeAlertsEnabled = runtimeAlertsEnabled
    }

    func requestAuthorization() async { await delivery.requestAuthorization() }
    func authorizationSummary() async -> String { await delivery.authorizationSummary() }
    func update(reason: CalendarAutomationAttentionReason?) {
        let enabled = runtimeAlertsEnabled()
        updateSequence &+= 1
        let sequence = updateSequence
        Task { await alerts.update(reason: reason, runtimeAlertsEnabled: enabled, sequence: sequence) }
    }
}

@MainActor
final class CalendarUserNotificationDelivery: NSObject, CalendarAutomationNotificationDelivering,
    UNUserNotificationCenterDelegate
{
    private static let notificationIdentifier = "calendar-automation-attention"
    private let center = UNUserNotificationCenter.current()
    private let showControlPanel: () -> Void

    init(showControlPanel: @escaping () -> Void) {
        self.showControlPanel = showControlPanel
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async { _ = try? await center.requestAuthorization(options: [.alert]) }

    func authorizationSummary() async -> String {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return "Not requested. Actionable recovery opens in CalRelay."
        case .denied: return "Denied. Scheduling remains available; actionable recovery opens in CalRelay."
        case .authorized, .provisional:
            return Self.alertsAvailable(settings)
                ? "Authorized for actionable recovery and overdue-freshness alerts."
                : "Alerts are unavailable. Actionable recovery opens in CalRelay."
        @unknown default: return "Unavailable. Actionable recovery opens in CalRelay."
        }
    }

    func notificationsAvailable() async -> Bool { Self.alertsAvailable(await center.notificationSettings()) }

    func submitNotification(_ notification: CalendarAutomationAttentionNotification) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: nil)
        do {
            try await center.add(request)
            return true
        } catch { return false }
    }

    func clearNotification() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
    }

    func openControlPanel() async { showControlPanel() }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [.banner, .list] }

    private static func alertsAvailable(_ settings: UNNotificationSettings) -> Bool {
        (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            && settings.alertSetting == .enabled && settings.alertStyle != .none
    }
}
