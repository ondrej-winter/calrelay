import ServiceManagement

enum CalendarLaunchAtLoginState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

struct CalendarLaunchAtLoginController {
    private let isEnabled: Bool
    private let service = SMAppService.mainApp

    init(isEnabled: Bool = true) { self.isEnabled = isEnabled }

    func currentState() -> CalendarLaunchAtLoginState {
        guard isEnabled else { return .enabled }
        return switch service.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func enable() throws {
        guard isEnabled else { return }
        guard service.status != .enabled else { return }
        try service.register()
    }
}