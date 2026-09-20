import SwiftUI

struct CalendarListView: View {
    @StateObject var viewModel: CalendarListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statusPanel
            statusControls
            calendarAccessControls
            inventoryControls
            syncControls
            schedulingControls
            if viewModel.isMigrationPending { cleanupControls }
            calendarOutput
        }.padding().task { viewModel.start() }.sheet(item: $viewModel.manualReview) { review in
            VStack(alignment: .leading, spacing: 16) {
                Text("Review Sync Plan").font(.title2).accessibilityIdentifier("manual-review-title")
                Text(viewModel.reviewNotice).accessibilityIdentifier("manual-review-notice")
                Text("Planned deletes: \(review.summary.plannedDeletes)").accessibilityIdentifier(
                    "manual-review-deletes")
                Text("Planned creates: \(review.summary.plannedCreates)").accessibilityIdentifier(
                    "manual-review-creates")
                Text(
                    "Confirmation applies only to this ordered plan. Current configuration and calendars will be checked again before any mutation."
                )
                HStack {
                    Button("Cancel") { viewModel.cancelSyncReview() }.keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("manual-review-cancel")
                    Spacer()
                    Button(viewModel.isLoading ? "Checking and applying…" : "Confirm Run Sync") {
                        viewModel.confirmSync()
                    }.accessibilityIdentifier("manual-review-confirm")
                }.disabled(viewModel.isLoading)
            }.padding(24).frame(width: 460).interactiveDismissDisabled()
        }.sheet(item: $viewModel.cleanupReview) { review in
            CalendarCleanupReviewView(viewModel: viewModel, review: review)
        }.sheet(item: $viewModel.standingAuthorizationReview) { review in
            VStack(alignment: .leading, spacing: 16) {
                Text("Authorize Scheduled Sync").font(.title2).accessibilityIdentifier(
                    "standing-authorization-review-title")
                Text(viewModel.standingAuthorizationNotice).accessibilityIdentifier(
                    "standing-authorization-review-notice")
                Text("Planned deletes in this fresh dry run: \(review.summary.plannedDeletes)")
                Text("Planned creates in this fresh dry run: \(review.summary.plannedCreates)")
                Text(
                    "Authorization is bound to the current configuration, reconciliation policy, and resolved physical calendar topology. It does not authorize manual sync or legacy cleanup."
                )
                HStack {
                    Button("Cancel") { viewModel.cancelStandingAuthorizationReview() }.keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("standing-authorization-review-cancel")
                    Spacer()
                    Button(viewModel.isLoading ? "Checking…" : "Enable Scheduled Sync") {
                        viewModel.confirmStandingAuthorization()
                    }.accessibilityIdentifier("standing-authorization-review-confirm")
                }.disabled(viewModel.isLoading)
            }.padding(24).frame(width: 500).interactiveDismissDisabled()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CalRelay").font(.largeTitle)
            Text(
                "Verify Calendar access, inspect visible calendars, and review or explicitly confirm an ordinary sync."
            ).foregroundStyle(.secondary)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current app status").font(.headline)
            Text(viewModel.primaryStatus).font(.title3).fontWeight(.semibold).accessibilityIdentifier("primary-status")
            StatusRow(label: "Configuration", value: viewModel.configurationSummary, identifier: "configuration-status")
            StatusRow(
                label: "Calendar access", value: viewModel.authorizationSummary, identifier: "calendar-access-status")
            StatusRow(label: "Configured readiness", value: viewModel.readinessSummary, identifier: "readiness-status")
            StatusRow(label: "Migration", value: viewModel.migrationSummary, identifier: "migration-status")
            StatusRow(
                label: "Scheduled sync authorization", value: viewModel.standingAuthorizationSummary,
                identifier: "standing-authorization-status")
            StatusRow(label: "Scheduling", value: viewModel.schedulingSummary, identifier: "scheduling-status")
            StatusRow(
                label: "Launch at login", value: viewModel.launchAtLoginSummary, identifier: "launch-at-login-status")
            StatusRow(
                label: "Automatic operation", value: viewModel.automaticOperationSummary,
                identifier: "automatic-operation-status")
            StatusRow(
                label: "Automation attention", value: viewModel.automationAttentionSummary,
                identifier: "automation-attention-status")
            StatusRow(
                label: "User notifications", value: viewModel.notificationSummary, identifier: "notification-status")
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusControls: some View {
        Button(viewModel.isLoading ? "Refreshing…" : "Refresh Status") { viewModel.refreshStatus() }.disabled(
            viewModel.isOperationBlocked
        ).accessibilityIdentifier("refresh-status").help(
            "Reload the canonical configuration and check Calendar access and configured readiness without prompting.")
    }

    private var calendarAccessControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Checking…" : "Set Up or Recover Calendar Access") {
                viewModel.setUpCalendarAccess()
            }.disabled(viewModel.isOperationBlocked).accessibilityIdentifier("setup-calendar-access")

            Text("This is the only CalRelay action that may trigger the macOS Calendar permission prompt.").font(
                .footnote
            ).foregroundStyle(.secondary)
        }
    }

    private var inventoryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Loading…" : "Show Calendar Inventory") { viewModel.listCalendars() }.disabled(
                viewModel.isOperationBlocked
            ).accessibilityIdentifier("show-calendar-inventory")

            Text(
                "Inventory requires pre-existing full access, never prompts, omits EventKit IDs, and does not verify configured readiness."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var syncControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Planning…" : "Dry Run Sync") { viewModel.runDryRun() }.disabled(
                viewModel.isOperationBlocked || !viewModel.canRunOrdinarySync
            ).accessibilityIdentifier("dry-run-sync")
            Button("Run Sync Now") { viewModel.reviewSync() }.disabled(
                viewModel.isOperationBlocked || !viewModel.canRunOrdinarySync
            ).accessibilityIdentifier("run-sync-now")

            Text(
                "Loads fresh configuration and Calendar state, runs the complete ordinary readiness preflight, and shows only aggregate create/delete counts without mutation."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var schedulingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Review and Enable Scheduled Sync…") { viewModel.reviewStandingAuthorization() }.disabled(
                viewModel.isOperationBlocked || !viewModel.canReviewStandingAuthorization
            ).accessibilityIdentifier("review-scheduled-sync")
            if viewModel.isSchedulingEnabled {
                Button("Pause Scheduled Sync") { viewModel.pauseScheduling() }.disabled(viewModel.isOperationBlocked)
                    .accessibilityIdentifier("pause-scheduled-sync")
            } else if viewModel.isSchedulingPaused {
                Button("Resume Scheduled Sync") { viewModel.resumeScheduling() }.disabled(viewModel.isOperationBlocked)
                    .accessibilityIdentifier("resume-scheduled-sync")
            }
            Button("Enable Launch at Login") { viewModel.enableLaunchAtLogin() }.disabled(viewModel.isOperationBlocked)
                .accessibilityIdentifier("enable-launch-at-login")
            Text(
                "Runs a fresh non-mutating ordinary dry run, then asks for standing authorization covering launch, wake, the fixed 15-minute timer, and bounded retries."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var cleanupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Dry Run Legacy Cleanup") { viewModel.reviewCleanup(forApply: false) }.accessibilityIdentifier(
                    "dry-run-legacy-cleanup")
                Button("Run Legacy Cleanup…") { viewModel.reviewCleanup(forApply: true) }.accessibilityIdentifier(
                    "run-legacy-cleanup")
            }.disabled(viewModel.isOperationBlocked || !viewModel.canReviewCleanup)
            Text(
                "Separate full-range preflight and detailed review. Cleanup deletes only legacy-marker matches, requires explicit confirmation, and leaves configuration unchanged."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var calendarOutput: some View {
        ScrollView {
            Text(viewModel.output).font(.system(.body, design: .monospaced)).frame(
                maxWidth: .infinity, alignment: .leading
            ).textSelection(.enabled).padding().accessibilityIdentifier("operation-output")
        }.background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusRow: View {
    let label: String
    let value: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }.accessibilityElement(children: .combine).accessibilityIdentifier(identifier).accessibilityLabel(
            "\(label): \(value)")
    }
}
