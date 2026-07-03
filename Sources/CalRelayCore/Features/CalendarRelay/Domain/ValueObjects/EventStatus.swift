public enum EventStatus: Equatable, Sendable, CustomStringConvertible {
    case confirmed
    case tentative
    case cancelled
    case declined
    case unknown

    public var description: String {
        switch self {
        case .confirmed: "confirmed"
        case .tentative: "tentative"
        case .cancelled: "cancelled"
        case .declined: "declined"
        case .unknown: "unknown"
        }
    }
}