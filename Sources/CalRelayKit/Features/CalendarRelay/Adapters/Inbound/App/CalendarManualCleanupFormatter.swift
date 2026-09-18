import Foundation

public enum CalendarManualCleanupFormatter {
    public static func formatReview(_ review: CalendarManualCleanupReview) -> String {
        let formatter = DateFormatter()
        formatter.calendar = review.calendar
        formatter.timeZone = review.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
        var lines = [
            "Cleanup range: \(formatter.string(from: review.window.start)) → \(formatter.string(from: review.window.end)) (end exclusive).",
            "Selected deletions: \(review.rows.count)"
        ]
        for row in review.rows {
            formatter.dateFormat = row.isAllDay ? "yyyy-MM-dd" : "yyyy-MM-dd HH:mm zzz"
            let kind = row.isAllDay ? "all-day dates; end exclusive" : "time range"
            lines.append("- \(row.role.description): \(row.title) [\(kind): \(formatter.string(from: row.start)) → \(formatter.string(from: row.end))]")
        }
        return lines.joined(separator: "\n")
    }

    public static func formatSuccess(confirmedDeletions: Int) -> String {
        "Cleanup verified in the complete local range. Confirmed deletions: \(confirmedDeletions). "
            + "This is local and point-in-time, not proof of global or historical retirement. "
            + "Configuration was not changed. Remove legacyMarkers manually only when migration is complete for your topology."
    }

    public static func formatFailure(_ error: Error) -> String {
        guard let error = error as? CalendarManualCleanupError else {
            return "Cleanup could not be completed. Refresh status and review a fresh cleanup plan."
        }
        switch error {
        case .operationInProgress: return "An operation is already in progress. Wait for it to finish."
        case .reviewRequired: return "Cleanup confirmation is no longer valid. Review a fresh cleanup plan."
        case .configurationChanged: return "Configuration changed before deletion. Nothing was deleted. Review a fresh cleanup plan."
        case .failed(let count, let category):
            return "Cleanup unsuccessful. Confirmed deletions: \(count). \(message(category)) "
                + "Confirmed deletions remain applied; no rollback was attempted. Refresh status, resolve the issue, then review and confirm a fresh cleanup plan."
        }
    }

    private static func message(_ category: CalendarManualCleanupFailure) -> String {
        switch category {
        case .configurationUnavailable: "The canonical configuration is missing or invalid."
        case .legacyMarkersRequired: "Cleanup requires configured legacy markers."
        case .authorizationUnavailable(let state): CalendarAccessError.fullAccessRequired(state).description
        case .preflightFailed: "Complete cleanup-range preflight failed. Check every configured calendar."
        case .deletionFailed: "Deletion failed; later deletions were not attempted."
        case .verificationReadFailed: "The complete cleanup range could not be read for verification."
        case .remainingMatches(let count): "Verification found \(count) remaining matching event(s)."
        case .cancelled: "Cleanup was cancelled."
        case .unexpected: "Cleanup could not be completed."
        }
    }
}