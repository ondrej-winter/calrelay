import CalRelayKit
import SwiftUI

@MainActor final class CalendarListViewModel: ObservableObject {
    @Published var output = "Use the setup or recovery action, then show the separate calendar inventory."
    @Published var primaryStatus = "Status has not been refreshed."
    @Published var configurationSummary = "Configuration has not been checked."
    @Published var authorizationSummary = "Calendar access has not been checked in this app session."
    @Published var readinessSummary = "Configured readiness has not been checked."
    @Published var migrationSummary = "Migration state has not been checked."
    @Published var isLoading = false
    @Published var canRunOrdinarySync = false

    private let inventory: CalendarInventoryUseCase
    private let setup: CalendarAccessSetupUseCase
    private let status: CalendarControlPanelStatusUseCase
    private let manualDryRun: CalendarManualDryRunUseCase

    init(
        inventory: CalendarInventoryUseCase, setup: CalendarAccessSetupUseCase,
        status: CalendarControlPanelStatusUseCase, manualDryRun: CalendarManualDryRunUseCase
    ) {
        self.inventory = inventory
        self.setup = setup
        self.status = status
        self.manualDryRun = manualDryRun
    }

    func refreshStatus() {
        isLoading = true
        canRunOrdinarySync = false
        output = "Refreshing configuration, Calendar access, and configured readiness…"

        Task {
            do {
                apply(try await status.run())
                output = "Status refresh completed without requesting Calendar access."
            } catch {
                primaryStatus = "Status refresh failed."
                canRunOrdinarySync = false
                output = "Status could not be refreshed. Check the configuration and try again."
            }

            isLoading = false
        }
    }

    func setUpCalendarAccess() {
        isLoading = true
        canRunOrdinarySync = false
        output = "Checking Calendar access…"

        Task {
            do {
                let result = try await setup.run()
                authorizationSummary = Self.authorizationSummary(for: result.authorizationState)
                let setupOutput =
                    result.didRequestAccess
                    ? "Calendar access request completed. Review the authorization state above."
                    : "Calendar access was checked without showing a permission prompt."
                do {
                    apply(try await status.run())
                    output = setupOutput + " Status was refreshed."
                } catch {
                    canRunOrdinarySync = false
                    output = setupOutput + " Status refresh failed; use Refresh Status to try again."
                }
            } catch {
                authorizationSummary = "Calendar access setup failed."
                output = Self.safeErrorMessage(error)
            }

            isLoading = false
        }
    }

    private func apply(_ status: CalendarControlPanelStatus) {
        primaryStatus = Self.primaryStatus(for: status.primaryState)
        configurationSummary = Self.configurationSummary(for: status.configurationState)
        authorizationSummary =
            status.authorizationState.map(Self.authorizationSummary(for:))
            ?? "Calendar access was not checked because configuration must be fixed first."
        readinessSummary = Self.readinessSummary(for: status.readinessState)
        migrationSummary =
            status.isMigrationPending
            ? "Migration is pending. Ordinary sync remains blocked until explicit cleanup completes and legacyMarkers is removed manually."
            : "No legacy-marker migration is pending."
        canRunOrdinarySync = status.primaryState == .ready
    }

    private static func primaryStatus(for state: CalendarControlPanelPrimaryState) -> String {
        switch state {
        case .configurationMissing: "Configuration is missing. Create the canonical YAML file first."
        case .configurationInvalid: "Configuration is invalid. Fix the YAML before checking Calendar access."
        case .calendarAccessUnavailable: "Full Calendar access is unavailable. Use the setup or recovery action."
        case .topologyNotReady: "Configured calendars are not currently ready. Review the readiness issues."
        case .migrationPending: "Configured topology is ready, but explicit legacy cleanup is required."
        case .ready: "Calendar access and the complete configured topology are currently ready."
        }
    }

    private static func configurationSummary(for state: CalendarControlPanelConfigurationState) -> String {
        switch state {
        case .missing(let displayPath): "Missing: \(displayPath)"
        case .invalid(let displayPath): "Invalid: \(displayPath)"
        case .valid(let displayPath): "Valid: \(displayPath)"
        }
    }

    private static func readinessSummary(for state: CalendarControlPanelReadinessState) -> String {
        switch state {
        case .notChecked: "Not checked."
        case .ready: "Every configured role resolved uniquely, was writable, and was readable over the ordinary window."
        case .notReady(let issues): issues.map(\.description).joined(separator: "\n")
        }
    }

    func listCalendars() {
        isLoading = true
        output = "Loading the non-prompting Calendar inventory…"

        Task {
            do { output = CalendarListFormatter.formatForApp(try await inventory.run()) } catch {
                output = Self.safeErrorMessage(error)
            }

            isLoading = false
        }
    }

    func runDryRun() {
        isLoading = true
        output = "Loading fresh configuration and Calendar state for a dry run…"

        Task {
            do { output = CalendarManualDryRunFormatter.format(try await manualDryRun.run()) } catch {
                canRunOrdinarySync = false
                output = Self.safeOperationErrorMessage(error)
            }

            isLoading = false
        }
    }

    private static func authorizationSummary(for state: CalendarAuthorizationState) -> String {
        switch state {
        case .notDetermined: "Calendar access is not determined. Use this setup action to request full access."
        case .restricted: "Calendar access is restricted and must be resolved outside CalRelay."
        case .denied: "Calendar access is denied or revoked. Enable full access in System Settings."
        case .writeOnly: "Calendar access is write-only. Enable full access in System Settings."
        case .fullAccess:
            "Full Calendar access is available. Inventory and configured readiness remain separate checks."
        case .unknown:
            "The Calendar authorization state is unavailable. CalRelay will not request or use access automatically."
        }
    }

    private static func safeErrorMessage(_ error: Error) -> String {
        if let calendarAccessError = error as? CalendarAccessError { return calendarAccessError.description }
        return "Calendar access could not be completed. Try the setup or recovery action again."
    }

    private static func safeOperationErrorMessage(_ error: Error) -> String {
        if let providerError = error as? CalendarRelaySettingsProviderError {
            switch providerError {
            case .missing: return "The canonical configuration file is missing. Create it, then refresh status."
            case .invalid: return "The canonical configuration file is invalid. Fix it, then refresh status."
            }
        }
        if let reconciliationError = error as? ReconcileCalendarsError { return reconciliationError.description }
        if let calendarAccessError = error as? CalendarAccessError { return calendarAccessError.description }
        return "The dry run could not be completed. Refresh status, resolve the reported prerequisite, and try again."
    }
}
