import Foundation

public struct IdentifiableURL: Identifiable {
    public let id = UUID()
    public let url: URL
    public let isVideo: Bool

    public init(url: URL, isVideo: Bool = false) {
        self.url = url
        self.isVideo = isVideo
    }
}
