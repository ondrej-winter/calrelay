public enum MarkerSyntax {
    public static func isValid(_ marker: String) -> Bool {
        guard marker.first == "[", marker.last == "]" else { return false }
        let identifier = marker.dropFirst().dropLast()
        guard !identifier.isEmpty else { return false }
        return identifier.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 45, 48...57, 65...90, 95, 97...122: true
            default: false
            }
        }
    }
}
