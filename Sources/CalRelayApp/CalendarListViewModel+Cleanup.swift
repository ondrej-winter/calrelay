import CalRelayKit

extension CalendarListViewModel {
    func reviewCleanup(forApply: Bool) {
        guard !isOperationBlocked else { return }
        isLoading = true
        output = "Loading a fresh cleanup plan over the complete cleanup range…"
        Task {
            defer { isLoading = false }
            do {
                let review = try await manualCleanup.review()
                cleanupNotice = "Successful fresh cleanup dry run. Nothing has been deleted."
                cleanupAllowsConfirmation = forApply
                cleanupReview = review
            } catch {
                canReviewCleanup = false
                output = CalendarManualCleanupFormatter.formatFailure(error)
            }
        }
    }

    func cancelCleanupReview() {
        guard !isLoading, cleanupReview != nil else { return }
        isLoading = true
        Task {
            await manualCleanup.cancelReview()
            cleanupReview = nil
            cleanupAllowsConfirmation = false
            output = "Cleanup review closed. No calendar mutations were performed."
            isLoading = false
        }
    }

    func confirmCleanup() {
        guard !isLoading, cleanupAllowsConfirmation, let review = cleanupReview else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                switch try await manualCleanup.confirm(reviewID: review.id) {
                case .reviewRequired(let fresh):
                    cleanupNotice =
                        "The plan, range, or configuration changed. Nothing was deleted. Review this fresh ordered plan and confirm again."
                    cleanupReview = fresh
                case .applied(let count):
                    cleanupReview = nil
                    cleanupAllowsConfirmation = false
                    output = CalendarManualCleanupFormatter.formatSuccess(confirmedDeletions: count)
                }
            } catch {
                cleanupReview = nil
                cleanupAllowsConfirmation = false
                canReviewCleanup = false
                output = CalendarManualCleanupFormatter.formatFailure(error)
            }
        }
    }
}
