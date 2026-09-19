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
    private var nominalTimer: Timer?
    private var retryTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var onTrigger: ((CalendarAutomaticTrigger, Date?) -> Void)?

    func start(onTrigger: @escaping (CalendarAutomaticTrigger, Date?) -> Void) -> Date {
        stop()
        self.onTrigger = onTrigger
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onTrigger?(.wake, nil) }
        }
        return scheduleNominalTimer()
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
        retryTimer?.invalidate()
        retryTimer = nil
        guard case .scheduled(_, let nextAttemptAt) = state else { return }
        retryTimer = Timer.scheduledTimer(
            withTimeInterval: max(0, nextAttemptAt.timeIntervalSinceNow), repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.retryTimer = nil
                self?.onTrigger?(.retry, nil)
            }
        }
    }

    private func scheduleNominalTimer() -> Date {
        let interval = CalendarAutomationSchedulingPolicy.nominalInterval
        let nextNominalRunAt = Date().addingTimeInterval(interval)
        nominalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onTrigger?(.timer, Date().addingTimeInterval(interval))
            }
        }
        return nextNominalRunAt
    }
}