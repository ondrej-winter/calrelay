public enum EventAvailability: Equatable, Sendable, CustomStringConvertible {
    case busy
    case tentative
    case free
    case unavailable
    case notSupported
    case unknown

    public var description: String {
        switch self {
        case .busy: "busy"
        case .tentative: "tentative"
        case .free: "free"
        case .unavailable: "unavailable"
        case .notSupported: "notSupported"
        case .unknown: "unknown"
        }
    }
}