import Foundation

public enum CalendarCleanupFormatter {
    public static func formatDryRun(
        _ plan: CalendarCleanupPlan, window: CalendarAccessWindow, configuredRoles: [ConfiguredCalendarRole]
    ) -> String {
        let heading =
            plan.deletions.isEmpty
            ? "Cleanup dry-run found no matching legacy-marker events in the loaded local snapshot."
            : "Cleanup dry-run. No calendar mutations were performed."
        return formatReview(plan, window: window, configuredRoles: configuredRoles, heading: heading)
    }

    public static func formatFreshApplyPlan(
        _ plan: CalendarCleanupPlan, window: CalendarAccessWindow, configuredRoles: [ConfiguredCalendarRole]
    ) -> String {
        formatReview(
            plan, window: window, configuredRoles: configuredRoles,
            heading: "Fresh cleanup plan before mutation. A prior cleanup dry-run is recommended but not required. "
                + "--apply authorizes this non-interactive cleanup without proof of an earlier dry-run or additional confirmation."
        )
    }

    public static func formatVerifiedSuccess(_ result: CalendarCleanupApplyResult) -> String {
        let completion =
            result.confirmedDeletionCount == 0
            ? "Cleanup succeeded"
            : "Cleanup succeeded after \(result.confirmedDeletionCount) confirmed \(deletionLabel(result.confirmedDeletionCount))"
        return completion + ": the post-mutation verification snapshot contained no matching legacy-marker events, "
            + "so cleanup verified no matching legacy-marker events in the complete configured range. "
            + "This is local and point-in-time, not proof of global or historical marker retirement. "
            + "Configuration was not changed. Remove legacyMarkers manually only after the eventual-convergence migration "
            + "is complete for your topology."
    }

    private static func formatReview(
        _ plan: CalendarCleanupPlan, window: CalendarAccessWindow, configuredRoles: [ConfiguredCalendarRole],
        heading: String
    ) -> String {
        let countsByRole = plan.deletions.reduce(into: [ConfiguredCalendarRole: Int]()) { counts, deletion in
            counts[deletion.role, default: 0] += 1
        }
        var lines = [
            heading,
            "Cleanup range: \(window.start.description) → \(window.end.description) (local point-in-time scope; end exclusive).",
            "Configured roles covered: \(configuredRoles.count)"
        ]
        lines.append(contentsOf: configuredRoles.map { roleSummary($0, count: countsByRole[$0, default: 0]) })
        lines.append("Selected deletions: \(plan.deletions.count)")
        lines.append(contentsOf: plan.deletions.map(formatDeletion))
        lines.append("This result does not prove global or historical marker retirement.")
        return lines.joined(separator: "\n")
    }

    private static func roleSummary(_ role: ConfiguredCalendarRole, count: Int) -> String {
        "- \(role.description): \(count) selected \(deletionLabel(count))"
    }

    private static func deletionLabel(_ count: Int) -> String { count == 1 ? "deletion" : "deletions" }

    private static func formatDeletion(_ deletion: CalendarCleanupDeletion) -> String {
        let range =
            deletion.event.isAllDay
            ? "all-day dates; end exclusive: \(deletion.event.start.description) → \(deletion.event.end.description)"
            : "time range: \(deletion.event.start.description) → \(deletion.event.end.description)"
        return "- delete from \(deletion.role.description): \(reviewTitle(deletion.event.title)) [\(range)]"
    }

    private static func reviewTitle(_ title: String) -> String {
        guard let marker = MarkedEventTitle.marker(in: title) else { return title }
        return String(title.dropFirst(marker.count + 1))
    }
}
