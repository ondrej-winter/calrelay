import Foundation

public enum CalendarAuthorizationState: CaseIterable, Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case writeOnly
    case fullAccess
    case unknown
}

public enum CalendarAccessError: Error, Equatable, CustomStringConvertible, Sendable {
    case fullAccessRequired(CalendarAuthorizationState)

    public var description: String {
        switch self {
        case .fullAccessRequired(.notDetermined):
            "Full Calendar access has not been granted. Open CalRelay.app and use its Calendar access setup action."
        case .fullAccessRequired(.restricted):
            "Calendar access is restricted on this Mac and must be resolved outside CalRelay."
        case .fullAccessRequired(.denied):
            "Calendar access was denied or revoked. Enable full access for CalRelay in System Settings."
        case .fullAccessRequired(.writeOnly):
            "Calendar access is write-only. Enable full access for CalRelay in System Settings."
        case .fullAccessRequired(.fullAccess): "Full Calendar access is required."
        case .fullAccessRequired(.unknown):
            "Calendar authorization is unavailable. Open CalRelay.app for setup or recovery guidance."
        }
    }
}

public struct CalendarAccessSetupResult: Equatable, Sendable {
    public let authorizationState: CalendarAuthorizationState
    public let didRequestAccess: Bool

    public init(authorizationState: CalendarAuthorizationState, didRequestAccess: Bool) {
        self.authorizationState = authorizationState
        self.didRequestAccess = didRequestAccess
    }
}

public struct CalendarAccessWindow: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum ConfiguredCalendarRole: Equatable, Hashable, Sendable {
    case hub
    case work(name: String, declarationIndex: Int)
}

public enum CalendarAccessPreflightIssue: Equatable, CustomStringConvertible, Sendable {
    case authorizationUnavailable(CalendarAuthorizationState)
    case calendarInventoryReadFailed
    case calendarMissing(role: ConfiguredCalendarRole, selector: CalendarSelector)
    case calendarAmbiguous(role: ConfiguredCalendarRole, selector: CalendarSelector)
    case physicalCalendarCollision(roles: [ConfiguredCalendarRole])
    case calendarReadOnly(role: ConfiguredCalendarRole, selector: CalendarSelector)
    case eventReadFailed(role: ConfiguredCalendarRole, selector: CalendarSelector)

    public var description: String {
        switch self {
        case .authorizationUnavailable(let state): CalendarAccessError.fullAccessRequired(state).description
        case .calendarInventoryReadFailed: "Calendar inventory could not be read."
        case .calendarMissing(let role, let selector):
            "\(role.description) calendar was not found: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .calendarAmbiguous(let role, let selector):
            "\(role.description) calendar selector is ambiguous: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .physicalCalendarCollision(let roles):
            "Configured roles resolve to the same physical calendar: \(roles.map(\.description).joined(separator: ", "))."
        case .calendarReadOnly(let role, let selector):
            "\(role.description) calendar is read-only: \(selector.sourceTitle) / \(selector.calendarTitle)."
        case .eventReadFailed(let role, let selector):
            "Events could not be read for \(role.description): \(selector.sourceTitle) / \(selector.calendarTitle)."
        }
    }
}

extension ConfiguredCalendarRole: CustomStringConvertible {
    public var description: String {
        switch self {
        case .hub: "Hub"
        case .work(let name, _): "Work role \(name)"
        }
    }
}

public struct PreflightCalendarSnapshot: Equatable, Sendable {
    public let role: ConfiguredCalendarRole
    public let selector: CalendarSelector
    public let calendar: CalendarIdentity
    public let events: [CalendarEvent]

    public init(
        role: ConfiguredCalendarRole, selector: CalendarSelector, calendar: CalendarIdentity, events: [CalendarEvent]
    ) {
        self.role = role
        self.selector = selector
        self.calendar = calendar
        self.events = events
    }
}

public struct CalendarAccessPreflightSnapshot: Equatable, Sendable {
    public let window: CalendarAccessWindow
    public let calendars: [PreflightCalendarSnapshot]

    public init(window: CalendarAccessWindow, calendars: [PreflightCalendarSnapshot]) {
        self.window = window
        self.calendars = calendars
    }
}

public enum CalendarAccessPreflightResult: Equatable, Sendable {
    case ready(CalendarAccessPreflightSnapshot)
    case failed([CalendarAccessPreflightIssue])
}
