public enum MarkedEventTitle {
    public static func marker(in title: String) -> String? {
        guard let closingBracket = title.firstIndex(of: "]") else { return nil }
        let markerEnd = title.index(after: closingBracket)
        let marker = String(title[..<markerEnd])
        guard MarkerSyntax.isValid(marker), markerEnd < title.endIndex else { return nil }
        guard title[markerEnd] == " " else { return nil }

        let textStart = title.index(after: markerEnd)
        guard textStart < title.endIndex else { return nil }
        guard !title[textStart].isWhitespace else { return nil }
        return marker
    }
}
