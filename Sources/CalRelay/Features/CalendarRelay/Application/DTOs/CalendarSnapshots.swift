import Foundation

struct CalendarSelector: Equatable, Sendable {
    let sourceTitle: String
    let calendarTitle: String
}

struct CalendarSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String
    let isWritable: Bool
}

struct CalendarReference: Equatable, Hashable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String
}