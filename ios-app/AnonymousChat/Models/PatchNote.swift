import Foundation

public struct PatchNote: Codable, Identifiable {
    public var id: String { version }
    public let version: String
    public let date: String
    public let title: String
    public let items: [String]

    public init(version: String, date: String, title: String, items: [String]) {
        self.version = version
        self.date = date
        self.title = title
        self.items = items
    }
}
