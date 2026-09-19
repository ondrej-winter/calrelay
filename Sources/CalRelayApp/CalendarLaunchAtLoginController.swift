import ServiceManagement

enum CalendarLaunchAtLoginState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
}

struct CalendarLaunchAtLoginController {
    private let service = SMAppService.mainApp

    func currentState() -> CalendarLaunchAtLoginState {
        switch service.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    func enable() throws {
        guard service.status != .enabled else { return }
        try service.register()
    }
}