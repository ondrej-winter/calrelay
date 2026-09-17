import Foundation

public enum EventExplanationFormatter {
    public static func format(_ explanation: ReconciliationExplanation) -> String {
        let scopeOutput =
            "Effective window: \(formatRange(start: explanation.window.start, end: explanation.window.end)) "
            + "configuredForwardDays=\(explanation.syncWindowDays)"
        let candidateOutput =
            explanation.candidates.isEmpty
            ? "No candidate events found in the sync window."
            : (["Input events"] + explanation.candidates.map(formatCandidate)).joined(separator: "\n")
        let actionOutput =
            explanation.actions.isEmpty
            ? "Planned actions\nNo changes planned."
            : (["Planned actions"] + explanation.actions.map(formatAction)).joined(separator: "\n")
        return scopeOutput + "\n" + candidateOutput + "\n" + actionOutput
    }

    private static func formatCandidate(_ candidate: CandidateEventExplanation) -> String {
        let event = candidate.event

        return "- event-id=\(event.id.diagnosticIdentifier) calendar-id=\(event.calendar.id.diagnosticIdentifier) "
            + "\(formatCalendar(event.calendar)): \(event.title) "
            + "[\(formatRange(start: event.start, end: event.end))] "
            + "allDay=\(event.isAllDay) availability=\(event.availability) "
            + "status=\(event.status) eligibility=\(formatEligibility(candidate.eligibility)) "
            + "routing=\(formatRouting(candidate.routing)) expectation=\(formatExpectation(candidate.expectation)) "
            + "disposition=\(formatDisposition(candidate.disposition))"
    }

    private static func formatAction(_ explanation: PlannedActionExplanation) -> String {
        switch explanation.action {
        case .delete(let role, let event):
            return "- delete \(role.description) event-id=\(event.id.diagnosticIdentifier) "
                + "calendar-id=\(event.calendar.id.diagnosticIdentifier): \(event.title) "
                + "[\(formatRange(start: event.start, end: event.end))] reason=\(formatReason(explanation.reason))"
        case .create(let role, let event):
            let causalIDs = explanation.causalEvents.map { $0.id.diagnosticIdentifier }.joined(separator: ",")
            return "- create \(role.description) calendar-id=\(event.destinationCalendar.id.diagnosticIdentifier): "
                + "\(event.title) [\(formatRange(start: event.start, end: event.end))] "
                + "reason=\(formatReason(explanation.reason)) caused-by=\(causalIDs)"
        }
    }

    private static func formatEligibility(_ reason: CandidateEventEligibilityExplanation) -> String {
        switch reason {
        case .reliableCancellation: "excluded (reliably cancelled)"
        case .currentUserAccepted: "included (current-user attendee accepted)"
        case .currentUserNonAccepted(let status): "excluded (current-user attendee response: \(status))"
        case .noCurrentUserAttendeeIncluded(let availability):
            "included (no current-user attendee; availability: \(availability))"
        case .noCurrentUserAttendeeExcluded(let availability):
            "excluded (no current-user attendee; availability: \(availability))"
        case .markedHubEligibilityBypass: "included (valid marked hub eligibility bypass)"
        }
    }

    private static func formatRouting(_ routing: CandidateEventRoutingExplanation) -> String {
        switch routing {
        case .workToHubSource: "work-to-hub-source"
        case .hubPersonalSource: "hub-personal-source"
        case .exactLocalMarkerHubSource(let role): "exact-local-marker-hub-source(\(role.description))"
        case .nonLocalValidMarkerHubSource: "non-local-valid-marker-hub-source"
        case .cancelledMarkedHubPreservation: "cancelled-marked-hub-preservation"
        case .invalidOrUnmarkedHubSource: "invalid-or-unmarked-hub-source"
        case .feedbackSuppressedMarkedWorkProjection: "feedback-suppressed-marked-work-projection"
        }
    }

    private static func formatExpectation(_ expectation: CandidateEventExpectationExplanation) -> String {
        switch expectation {
        case .matchesExpectedProjection: "matches-expected-projection"
        case .noMatchingExpectation: "no-matching-expectation"
        }
    }

    private static func formatDisposition(_ disposition: CandidateEventDispositionExplanation) -> String {
        switch disposition {
        case .retained: "retained"
        case .preservedUnmanagedOrNonLocal: "preserved-unmanaged-or-non-local"
        case .selectedStaleManagedDeletion: "selected-stale-managed-deletion"
        case .selectedCancelledManagedDeletion: "selected-cancelled-managed-deletion"
        case .selectedDuplicateSetDeletion: "selected-replace-all-managed-duplicate-deletion"
        }
    }

    private static func formatReason(_ reason: PlannedActionExplanationReason) -> String {
        switch reason {
        case .missingExpectedProjection: "missing expected projection"
        case .staleManagedProjection: "stale managed projection"
        case .cancelledManagedProjection: "cancelled managed projection"
        case .replaceAllManagedDuplicate: "replace-all managed duplicate"
        }
    }

    private static func formatCalendar(_ calendar: CalendarIdentity) -> String {
        "\(calendar.sourceTitle) / \(calendar.title)"
    }

    private static func formatRange(start: Date, end: Date) -> String { "\(start.description) → \(end.description)" }
}
