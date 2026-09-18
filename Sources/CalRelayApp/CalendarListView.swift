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
            if viewModel.isMigrationPending { cleanupControls }
            calendarOutput
        }.padding().task { viewModel.refreshStatus() }.sheet(item: $viewModel.manualReview) { review in
            VStack(alignment: .leading, spacing: 16) {
                Text("Review Sync Plan").font(.title2)
                Text(viewModel.reviewNotice)
                Text("Planned deletes: \(review.summary.plannedDeletes)")
                Text("Planned creates: \(review.summary.plannedCreates)")
                Text(
                    "Confirmation applies only to this ordered plan. Current configuration and calendars will be checked again before any mutation."
                )
                HStack {
                    Button("Cancel") { viewModel.cancelSyncReview() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(viewModel.isLoading ? "Checking and applying…" : "Confirm Run Sync") {
                        viewModel.confirmSync()
                    }
                }.disabled(viewModel.isLoading)
            }.padding(24).frame(width: 460).interactiveDismissDisabled()
        }.sheet(item: $viewModel.cleanupReview) { review in
            CalendarCleanupReviewView(viewModel: viewModel, review: review)
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
            Text(viewModel.primaryStatus).font(.title3).fontWeight(.semibold)
            StatusRow(label: "Configuration", value: viewModel.configurationSummary)
            StatusRow(label: "Calendar access", value: viewModel.authorizationSummary)
            StatusRow(label: "Configured readiness", value: viewModel.readinessSummary)
            StatusRow(label: "Migration", value: viewModel.migrationSummary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusControls: some View {
        Button(viewModel.isLoading ? "Refreshing…" : "Refresh Status") { viewModel.refreshStatus() }.disabled(
            viewModel.isOperationBlocked
        ).help(
            "Reload the canonical configuration and check Calendar access and configured readiness without prompting.")
    }

    private var calendarAccessControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Checking…" : "Set Up or Recover Calendar Access") {
                viewModel.setUpCalendarAccess()
            }.disabled(viewModel.isOperationBlocked)

            Text("This is the only CalRelay action that may trigger the macOS Calendar permission prompt.").font(
                .footnote
            ).foregroundStyle(.secondary)
        }
    }

    private var inventoryControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Loading…" : "Show Calendar Inventory") { viewModel.listCalendars() }.disabled(
                viewModel.isOperationBlocked)

            Text(
                "Inventory requires pre-existing full access, never prompts, omits EventKit IDs, and does not verify configured readiness."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var syncControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(viewModel.isLoading ? "Planning…" : "Dry Run Sync") { viewModel.runDryRun() }.disabled(
                viewModel.isOperationBlocked || !viewModel.canRunOrdinarySync)
            Button("Run Sync Now") { viewModel.reviewSync() }.disabled(
                viewModel.isOperationBlocked || !viewModel.canRunOrdinarySync)

            Text(
                "Loads fresh configuration and Calendar state, runs the complete ordinary readiness preflight, and shows only aggregate create/delete counts without mutation."
            ).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var cleanupControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Dry Run Legacy Cleanup") { viewModel.reviewCleanup(forApply: false) }
                Button("Run Legacy Cleanup…") { viewModel.reviewCleanup(forApply: true) }
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
            ).textSelection(.enabled).padding()
        }.background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }.accessibilityElement(children: .combine)
    }
}
