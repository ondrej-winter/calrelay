import AppKit
import CalRelayKit
import UserNotifications

@MainActor final class CalendarAutomationAttentionController: NSObject, UNUserNotificationCenterDelegate {
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

        let content = UNMutableNotificationContent()
        content.title = "CalRelay needs attention"
        content.body = Self.notificationBody(reason)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier, content: content, trigger: nil)
        try? await center.add(request)
    }

    private static func notificationBody(_ reason: CalendarAutomationAttentionReason) -> String {
        switch reason {
        case .schedulingPaused: "Scheduled sync is paused."
        case .standingAuthorizationRequired: "Review a fresh dry run and renew scheduled sync authorization."
        case .launchAtLoginUnavailable: "Enable or approve CalRelay in Login Items."
        case .configurationUnavailable: "Restore or fix the canonical configuration file."
        case .migrationPending: "Complete explicit legacy cleanup before scheduled sync can resume."
        case .calendarAccessUnavailable: "Restore full Calendar access in the CalRelay control panel."
        case .topologyNotReady: "Resolve the configured calendar readiness issue."
        case .partialMutation: "A scheduled run partially applied and bounded retries are exhausted."
        case .transientFailure: "Scheduled sync retries are exhausted after a transient failure."
        case .freshnessOverdue: "No successful ordinary reconciliation has completed within the last hour."
        }
    }
}