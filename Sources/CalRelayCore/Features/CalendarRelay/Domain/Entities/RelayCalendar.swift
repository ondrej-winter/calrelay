public struct RelayCalendar: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let isWritable: Bool

    public init(id: String, title: String, sourceTitle: String, isWritable: Bool) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.isWritable = isWritable
    }
}