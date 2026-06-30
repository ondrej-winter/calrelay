import Foundation

struct EventSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let calendar: CalendarReference
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let availability: EventAvailability
    let status: EventStatus
}

enum EventAvailability: Equatable, Sendable {
    case busy
    case tentative
    case free
    case unavailable
    case unknown
}

enum EventStatus: Equatable, Sendable {
    case confirmed
    case tentative
    case cancelled
    case declined
    case unknown
}