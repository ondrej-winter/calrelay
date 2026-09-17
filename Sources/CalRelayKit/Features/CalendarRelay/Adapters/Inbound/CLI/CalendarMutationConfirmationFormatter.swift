public enum CalendarMutationConfirmationFormatter {
    public static func format(_ confirmation: CalendarMutationConfirmation) -> String {
        switch confirmation.category {
        case .delete: "Confirmed delete for \(confirmation.role.description)."
        case .create: "Confirmed create for \(confirmation.role.description)."
        }
    }
}
