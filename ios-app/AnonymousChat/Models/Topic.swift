import Foundation

public struct Topic: Codable, Identifiable {
    public var id: Int
    public var name: String
    public var totalMessages: Int
    public var onlineCount: Int
    public var isSystem: Bool
    public var isGeneral: Bool
    public var isOwner: Bool
    public var isLocked: Bool
    public var lockedBy: String?
    public var lastMsg: LastMessage?

    public struct LastMessage: Codable {
        public var id: Int?
        public var name: String?
        public var text: String?
        public var time: String?
    }

    public init(id: Int, name: String, totalMessages: Int = 0, onlineCount: Int = 0, isSystem: Bool = false, isGeneral: Bool = false, isOwner: Bool = false, isLocked: Bool = false, lockedBy: String? = nil, lastMsg: LastMessage? = nil) {
        self.id = id
        self.name = name
        self.totalMessages = totalMessages
        self.onlineCount = onlineCount
        self.isSystem = isSystem
        self.isGeneral = isGeneral
        self.isOwner = isOwner
        self.isLocked = isLocked
        self.lockedBy = lockedBy
        self.lastMsg = lastMsg
    }
}
