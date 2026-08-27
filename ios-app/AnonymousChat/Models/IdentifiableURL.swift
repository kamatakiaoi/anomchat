import Foundation

public struct IdentifiableURL: Identifiable {
    public let id = UUID()
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
