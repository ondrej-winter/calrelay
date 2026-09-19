import CalRelayKit

extension CalendarListViewModel {
    func reviewCleanup(forApply: Bool) {
        guard beginOperation(.cleanup) else { return }
        output = "Loading a fresh cleanup plan over the complete cleanup range…"
        Task {
            do {
                let review = try await manualCleanup.review()
                cleanupNotice = "Successful fresh cleanup dry run. Nothing has been deleted."
                cleanupAllowsConfirmation = forApply
                cleanupReview = review
                pauseOperationForReview()
            } catch {
                canReviewCleanup = false
                output = CalendarManualCleanupFormatter.formatFailure(error)
                finishOperation()
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
            finishOperation()
        }
    }

    func confirmCleanup() {
        guard !isLoading, cleanupAllowsConfirmation, let review = cleanupReview else { return }
        isLoading = true
        Task {
            do {
                switch try await manualCleanup.confirm(reviewID: review.id) {
                case .reviewRequired(let fresh):
                    cleanupNotice =
                        "The plan, range, or configuration changed. Nothing was deleted. Review this fresh ordered plan and confirm again."
                    cleanupReview = fresh
                    pauseOperationForReview()
                    return
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
            finishOperation()
        }
    }
}
