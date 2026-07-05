import Foundation

public struct ReconcileCommandHandler: Sendable {
    private let calendarStore: CalendarStorePort
    private let now: @Sendable () -> Date

    public init(
        calendarStore: CalendarStorePort = EventKitCalendarStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.calendarStore = calendarStore
        self.now = now
    }

    public func run(config: String?, apply: Bool, explain: Bool) async throws -> String {
        let selectedFile = try ConfigurationFileSelection.select(overridePath: config)
        let yaml = try String(contentsOfFile: selectedFile.path, encoding: .utf8)
        let settings = try YAMLCalendarRelaySettingsLoader.load(yaml)
        let useCase = ReconcileCalendarsUseCase(calendarStore: calendarStore)
        let currentDate = now()

        if explain {
            let explanation = try await useCase.explain(settings: settings, now: currentDate)
            return EventExplanationFormatter.format(explanation)
        }

        let plan =
            try await
            (apply ? useCase.apply(settings: settings, now: currentDate) : useCase.dryRun(settings: settings, now: currentDate))
        let modeMessage =
            apply
                ? "Apply mode. Planned calendar mutations were performed."
                : "Dry-run mode. No calendar mutations were performed."

        return [modeMessage, ReconciliationPlanFormatter.format(plan)].joined(separator: "\n")
    }
}