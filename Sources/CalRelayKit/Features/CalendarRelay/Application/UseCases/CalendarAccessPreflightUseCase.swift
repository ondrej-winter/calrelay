public struct CalendarAccessPreflightUseCase: Sendable {
    private let authorizationStatus: any CalendarAuthorizationStatusPort
    private let calendarStore: any CalendarStorePort

    public init(authorizationStatus: any CalendarAuthorizationStatusPort, calendarStore: any CalendarStorePort) {
        self.authorizationStatus = authorizationStatus
        self.calendarStore = calendarStore
    }

    public func run(settings: CalendarRelaySettings, window: CalendarAccessWindow) async throws
        -> CalendarAccessPreflightResult
    {
        let authorizationState = await authorizationStatus.authorizationStatus()
        guard authorizationState == .fullAccess else { return .failed([.authorizationUnavailable(authorizationState)]) }

        let inventory = try await loadCalendarInventory()
        guard case .loaded(let visibleCalendars) = inventory else {
            if case .failed(let issue) = inventory { return .failed([issue]) }
            return .failed([.calendarInventoryReadFailed])
        }

        let topology = resolveTopology(settings: settings, visibleCalendars: visibleCalendars)
        let reads = try await readSnapshots(resolutions: topology.resolutions, window: window)
        let issues = topology.issues + reads.issues
        guard issues.isEmpty else { return .failed(issues) }
        return .ready(CalendarAccessPreflightSnapshot(window: window, calendars: reads.snapshots))
    }

    private func loadCalendarInventory() async throws -> CalendarInventoryLoadResult {
        do { return .loaded(try await calendarStore.listCalendars()) } catch is CancellationError {
            throw CancellationError()
        } catch let error as CalendarAccessError { return .failed(authorizationIssue(from: error)) } catch {
            return .failed(.calendarInventoryReadFailed)
        }
    }

    private func resolveTopology(settings: CalendarRelaySettings, visibleCalendars: [RelayCalendar])
        -> TopologyResolutionResult
    {
        var result = TopologyResolutionResult()
        for descriptor in roleDescriptors(for: settings) {
            appendResolution(for: descriptor, visibleCalendars: visibleCalendars, to: &result)
        }
        appendCollisionIssues(for: result.resolutions, to: &result.issues)
        return result
    }

    private func appendResolution(
        for descriptor: RoleDescriptor, visibleCalendars: [RelayCalendar], to result: inout TopologyResolutionResult
    ) {
        let matches = visibleCalendars.filter { calendar in
            calendar.sourceTitle == descriptor.selector.sourceTitle
                && calendar.title == descriptor.selector.calendarTitle
        }
        switch matches.count {
        case 0: result.issues.append(.calendarMissing(role: descriptor.role, selector: descriptor.selector))
        case 1:
            if let calendar = matches.first {
                result.resolutions.append(RoleResolution(descriptor: descriptor, calendar: calendar))
            }
        default: result.issues.append(.calendarAmbiguous(role: descriptor.role, selector: descriptor.selector))
        }
    }

    private func readSnapshots(resolutions: [RoleResolution], window: CalendarAccessWindow) async throws
        -> SnapshotReadResult
    {
        var result = SnapshotReadResult()
        for resolution in resolutions {
            if !resolution.calendar.isWritable {
                result.issues.append(
                    .calendarReadOnly(role: resolution.descriptor.role, selector: resolution.descriptor.selector))
            }
            try await readSnapshot(resolution: resolution, window: window, result: &result)
        }
        return result
    }

    private func readSnapshot(
        resolution: RoleResolution, window: CalendarAccessWindow, result: inout SnapshotReadResult
    ) async throws {
        let calendar = CalendarIdentity(
            id: resolution.calendar.id, title: resolution.calendar.title, sourceTitle: resolution.calendar.sourceTitle)
        do {
            let events = try await calendarStore.events(in: calendar, from: window.start, to: window.end)
            result.snapshots.append(
                PreflightCalendarSnapshot(
                    role: resolution.descriptor.role, selector: resolution.descriptor.selector, calendar: calendar,
                    events: events))
        } catch is CancellationError { throw CancellationError() } catch let error as CalendarAccessError {
            let issue = authorizationIssue(from: error)
            if !result.issues.contains(issue) { result.issues.append(issue) }
        } catch {
            result.issues.append(
                .eventReadFailed(role: resolution.descriptor.role, selector: resolution.descriptor.selector))
        }
    }

    private func roleDescriptors(for settings: CalendarRelaySettings) -> [RoleDescriptor] {
        let hub = RoleDescriptor(role: .hub, selector: settings.hubCalendar.calendar)
        let workCalendars = settings.workCalendars.enumerated().map { index, workCalendar in
            RoleDescriptor(
                role: .work(name: workCalendar.name, declarationIndex: index), selector: workCalendar.calendar)
        }
        return [hub] + workCalendars
    }

    private func appendCollisionIssues(
        for resolutions: [RoleResolution], to issues: inout [CalendarAccessPreflightIssue]
    ) {
        var rolesByCalendarID: [String: [ConfiguredCalendarRole]] = [:]
        var calendarIDOrder: [String] = []

        for resolution in resolutions {
            if rolesByCalendarID[resolution.calendar.id] == nil { calendarIDOrder.append(resolution.calendar.id) }
            rolesByCalendarID[resolution.calendar.id, default: []].append(resolution.descriptor.role)
        }

        for calendarID in calendarIDOrder {
            guard let roles = rolesByCalendarID[calendarID], roles.count > 1 else { continue }
            issues.append(.physicalCalendarCollision(roles: roles))
        }
    }

    private func authorizationIssue(from error: CalendarAccessError) -> CalendarAccessPreflightIssue {
        switch error {
        case .fullAccessRequired(let state): .authorizationUnavailable(state)
        }
    }
}

private struct RoleDescriptor: Sendable {
    let role: ConfiguredCalendarRole
    let selector: CalendarSelector
}

private struct RoleResolution: Sendable {
    let descriptor: RoleDescriptor
    let calendar: RelayCalendar
}

private enum CalendarInventoryLoadResult {
    case loaded([RelayCalendar])
    case failed(CalendarAccessPreflightIssue)
}

private struct TopologyResolutionResult {
    var resolutions: [RoleResolution] = []
    var issues: [CalendarAccessPreflightIssue] = []
}

private struct SnapshotReadResult {
    var snapshots: [PreflightCalendarSnapshot] = []
    var issues: [CalendarAccessPreflightIssue] = []
}
