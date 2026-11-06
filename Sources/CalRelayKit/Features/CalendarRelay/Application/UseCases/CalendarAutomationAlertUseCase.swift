/// Coalesces recovery presentation within one app session without broadening mutation authority.
public actor CalendarAutomationAlertUseCase {
    private let port: any CalendarAutomationAlertPort
    private var currentReason: CalendarAutomationAttentionReason?
    private var didCheck = false
    private var revision: UInt = 0
    private var latestSequence: UInt = 0

    public init(port: any CalendarAutomationAlertPort) { self.port = port }

    /// Startup already has its own recovery presentation; record its state without duplicating alerts.
    /// Callers enqueueing independent tasks supply positive, increasing sequence numbers at the update source.
    /// Serial, awaiting callers may omit sequence; do not mix these modes within one session.
    public func update(
        reason: CalendarAutomationAttentionReason?, runtimeAlertsEnabled: Bool = true, sequence: UInt? = nil
    ) async {
        if let sequence {
            guard sequence > latestSequence else { return }
            latestSequence = sequence
        }
        guard !didCheck || currentReason != reason else { return }
        didCheck = true
        currentReason = reason
        revision &+= 1
        let requestRevision = revision
        guard let reason else {
            await port.clearNotification()
            return
        }
        guard runtimeAlertsEnabled, reason != .schedulingPaused else { return }
        let available = await port.notificationsAvailable()
        guard revision == requestRevision else { return }
        if available {
            let submitted = await port.submitNotification(CalendarAutomationAttentionNotification(reason: reason))
            guard revision == requestRevision else { return }
            if submitted { return }
        }
        await port.openControlPanel()
    }
}
