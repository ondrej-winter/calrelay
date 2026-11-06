import AppKit
import CalRelayKit
import Foundation

enum CalendarAutomaticTrigger {
    case launch
    case wake
    case timer
    case retry
}

@MainActor final class CalendarAutomationTriggerSource {
    private let isEnabled: Bool
    private let now: () -> Date
    private var nominalTimer: Timer?
    private var retryTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var onTrigger: ((CalendarAutomaticTrigger, Date?) -> Void)?

    init(isEnabled: Bool = true, now: @escaping () -> Date = Date.init) {
        self.isEnabled = isEnabled
        self.now = now
    }

    func start(onTrigger: @escaping (CalendarAutomaticTrigger, Date?) -> Void) -> Date {
        stop()
        self.onTrigger = onTrigger
        guard isEnabled else { return now().addingTimeInterval(CalendarAutomationSchedulingPolicy.nominalInterval) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.onTrigger?(.wake, nil) } }
        return scheduleNominalTimer()
    }

    func deliverTestTrigger(_ trigger: CalendarAutomaticTrigger) {
        guard !isEnabled else { return }
        onTrigger?(trigger, nil)
    }

    func stop() {
        nominalTimer?.invalidate()
        nominalTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        onTrigger = nil
    }

    func scheduleRetry(_ state: CalendarAutomationRetryState) {
        guard isEnabled else { return }
        retryTimer?.invalidate()
        retryTimer = nil
        guard case .scheduled(_, let nextAttemptAt) = state else { return }
        retryTimer = Timer.scheduledTimer(
            withTimeInterval: max(0, nextAttemptAt.timeIntervalSince(now())), repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.retryTimer = nil
                self?.onTrigger?(.retry, nil)
            }
        }
    }

    private func scheduleNominalTimer() -> Date {
        let interval = CalendarAutomationSchedulingPolicy.nominalInterval
        let nextNominalRunAt = now().addingTimeInterval(interval)
        nominalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onTrigger?(.timer, self.now().addingTimeInterval(interval))
            }
        }
        return nextNominalRunAt
    }
}
