import CalRelayKit
import SwiftUI

struct CalendarCleanupReviewView: View {
    @ObservedObject var viewModel: CalendarListViewModel
    let review: CalendarManualCleanupReview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.cleanupAllowsConfirmation ? "Review Legacy Cleanup" : "Legacy Cleanup Dry Run").font(.title2)
            Text(viewModel.cleanupNotice)
            ScrollView {
                Text(CalendarManualCleanupFormatter.formatReview(review)).font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(
                "Only these ordered deletions are reviewed. Confirmation reloads configuration and calendars; changed targets or order require new review. Verification covers only this local range, not global or historical retirement."
            ).font(.footnote)
            Text(
                "Retire legacy markers from every active publisher first. CalRelay will not edit YAML or enable ordinary sync after cleanup."
            ).font(.footnote)
            HStack {
                Button(viewModel.cleanupAllowsConfirmation ? "Cancel" : "Close") { viewModel.cancelCleanupReview() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if viewModel.cleanupAllowsConfirmation {
                    Button(
                        viewModel.isLoading ? "Checking, deleting and verifying…" : "Confirm Legacy Cleanup",
                        role: .destructive
                    ) { viewModel.confirmCleanup() }
                }
            }.disabled(viewModel.isLoading)
        }.padding(24).frame(width: 620, height: 500).interactiveDismissDisabled()
    }
}
