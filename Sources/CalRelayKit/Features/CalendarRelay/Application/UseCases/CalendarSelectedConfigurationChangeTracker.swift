public actor CalendarConfigurationChangeTracker {
    private var revision = 0

    public init() {}

    public func currentRevision() -> Int { revision }

    public func recordObservedChange() { revision += 1 }
}