/// Presentation boundary for privacy-safe recovery alerts; implementations own OS access.
public protocol CalendarAutomationAlertPort: Sendable {
    func notificationsAvailable() async -> Bool
    /// Returns false when submission fails; success does not prove user receipt.
    func submitNotification(_ notification: CalendarAutomationAttentionNotification) async -> Bool
    func clearNotification() async
    func openControlPanel() async
}
