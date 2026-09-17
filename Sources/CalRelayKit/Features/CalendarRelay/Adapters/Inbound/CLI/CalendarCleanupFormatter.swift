import Foundation

public enum CalendarCleanupFormatter {
    public static func formatDryRun(_ plan: CalendarCleanupPlan, window: CalendarAccessWindow) -> String {
        let heading =
            plan.deletions.isEmpty
            ? "Cleanup dry-run found no matching legacy-marker events in the loaded local snapshot."
            : "Cleanup dry-run. No calendar mutations were performed."
        return formatReview(plan, window: window, heading: heading)
    }

    public static func formatFreshApplyPlan(_ plan: CalendarCleanupPlan, window: CalendarAccessWindow) -> String {
        formatReview(plan, window: window, heading: "Fresh cleanup plan before mutation.")
    }

    public static func formatVerifiedSuccess(_ result: CalendarCleanupApplyResult) -> String {
        if result.confirmedDeletionCount == 0 {
            return "Cleanup succeeded: the complete verification snapshot verified no matching legacy-marker events."
        }
        return
            "Cleanup succeeded after \(result.confirmedDeletionCount) confirmed deletions; the complete verification snapshot verified no matching legacy-marker events."
    }

    private static func formatReview(_ plan: CalendarCleanupPlan, window: CalendarAccessWindow, heading: String)
        -> String
    {
        var lines = [
            heading,
            "Cleanup range: \(window.start.description) → \(window.end.description) (local point-in-time scope).",
            "Selected deletions: \(plan.deletions.count)"
        ]
        lines.append(contentsOf: plan.deletions.map(formatDeletion))
        lines.append("This result does not prove global or historical marker retirement.")
        return lines.joined(separator: "\n")
    }

    private static func formatDeletion(_ deletion: CalendarCleanupDeletion) -> String {
        let range =
            deletion.event.isAllDay
            ? "all-day \(deletion.event.start.description) → \(deletion.event.end.description)"
            : "\(deletion.event.start.description) → \(deletion.event.end.description)"
        return "- delete from \(deletion.role.description): \(reviewTitle(deletion.event.title)) [\(range)]"
    }

    private static func reviewTitle(_ title: String) -> String {
        guard let marker = MarkedEventTitle.marker(in: title) else { return title }
        return String(title.dropFirst(marker.count + 1))
    }
}
