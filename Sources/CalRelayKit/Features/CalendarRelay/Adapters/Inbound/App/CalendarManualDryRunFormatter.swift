public enum CalendarManualDryRunFormatter {
    public static func format(_ summary: CalendarManualDryRunSummary) -> String {
        """
        Dry run completed. No calendar mutations were performed.
        Planned deletes: \(summary.plannedDeletes)
        Planned creates: \(summary.plannedCreates)
        """
    }
}
