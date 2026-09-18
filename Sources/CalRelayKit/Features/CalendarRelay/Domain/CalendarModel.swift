import Foundation

public struct PhysicalCalendarReference: Equatable, Hashable, Sendable, CustomStringConvertible,
    CustomDebugStringConvertible
{
    private let providerIdentifier: String

    package init(providerIdentifier: String) { self.providerIdentifier = providerIdentifier }

    var eventKitIdentifier: String { providerIdentifier }
    var diagnosticIdentifier: String { providerIdentifier }
    var authorizationIdentityComponent: String { providerIdentifier }

    func syntheticEventReference(idPrefix: String, title: String, start: Date, end: Date) -> CalendarEventReference {
        CalendarEventReference(
            providerIdentifier:
                "\(idPrefix)-\(providerIdentifier)-\(title)-\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)"
        )
    }

    public var description: String { "<opaque-physical-calendar-reference>" }
    public var debugDescription: String { description }
}

public struct CalendarEventReference: Equatable, Hashable, Comparable, Sendable, CustomStringConvertible,
    CustomDebugStringConvertible
{
    private let providerIdentifier: String

    package init(providerIdentifier: String) { self.providerIdentifier = providerIdentifier }

    var eventKitIdentifier: String { providerIdentifier }
    var diagnosticIdentifier: String { providerIdentifier }

    func totalOrderKey(occurrenceDate: Date?) -> String {
        let occurrence = occurrenceDate?.timeIntervalSinceReferenceDate.description ?? ""
        return "\(providerIdentifier)|\(occurrence)"
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.providerIdentifier < rhs.providerIdentifier }

    public var description: String { "<opaque-calendar-event-reference>" }
    public var debugDescription: String { description }
}

public struct RelayCalendar: Equatable, Identifiable, Sendable {
    public let id: PhysicalCalendarReference
    public let title: String
    public let sourceTitle: String
    public let isWritable: Bool

    public init(id: String, title: String, sourceTitle: String, isWritable: Bool) {
        self.init(
            id: PhysicalCalendarReference(providerIdentifier: id), title: title, sourceTitle: sourceTitle,
            isWritable: isWritable)
    }

    public init(id: PhysicalCalendarReference, title: String, sourceTitle: String, isWritable: Bool) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.isWritable = isWritable
    }
}

public struct CalendarIdentity: Equatable, Hashable, Sendable {
    public let id: PhysicalCalendarReference
    public let title: String
    public let sourceTitle: String

    public init(id: String, title: String, sourceTitle: String) {
        self.init(id: PhysicalCalendarReference(providerIdentifier: id), title: title, sourceTitle: sourceTitle)
    }

    public init(id: PhysicalCalendarReference, title: String, sourceTitle: String) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
    }
}

public struct CalendarSelector: Equatable, Sendable {
    public let sourceTitle: String
    public let calendarTitle: String

    public init(sourceTitle: String, calendarTitle: String) {
        self.sourceTitle = sourceTitle
        self.calendarTitle = calendarTitle
    }
}

public struct CalendarEventIdentity: Equatable, Sendable {
    public let id: CalendarEventReference
    public let calendar: CalendarIdentity
    public let occurrenceDate: Date?
    public let lookupStart: Date?
    public let lookupEnd: Date?

    public init(
        id: String, calendar: CalendarIdentity, occurrenceDate: Date? = nil, lookupStart: Date? = nil,
        lookupEnd: Date? = nil
    ) {
        self.init(
            id: CalendarEventReference(providerIdentifier: id), calendar: calendar, occurrenceDate: occurrenceDate,
            lookupStart: lookupStart, lookupEnd: lookupEnd)
    }

    public init(
        id: CalendarEventReference, calendar: CalendarIdentity, occurrenceDate: Date? = nil, lookupStart: Date? = nil,
        lookupEnd: Date? = nil
    ) {
        self.id = id
        self.calendar = calendar
        self.occurrenceDate = occurrenceDate
        self.lookupStart = lookupStart
        self.lookupEnd = lookupEnd
    }
}
