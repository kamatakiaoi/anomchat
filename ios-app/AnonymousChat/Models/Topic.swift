import Foundation

public struct Topic: Codable, Identifiable {
    public var id: Int
    public var name: String
    public var msgCount: Int?
    public var online: Int?
    public var isSystem: Bool?
    public var isGeneral: Bool?
    public var locked: Bool?
    public var lockedBy: String?
    public var isOwner: Bool?
    public var recommended: Bool?
    public var lastMsg: LastMessage?

    public struct LastMessage: Codable {
        public var id: Int?
        public var name: String?
        public var text: String?
        public var time: String?
    }

    public var totalMessages: Int {
        return msgCount ?? 0
    }

    public var onlineCount: Int {
        return online ?? 0
    }

    public var isLocked: Bool {
        return locked ?? false
    }

    public var isSystemTopic: Bool {
        return isSystem ?? false
    }

    public var isGeneralTopic: Bool {
        return isGeneral ?? (name.lowercased() == "general")
    }

    public var isOwnerTopic: Bool {
        return isOwner ?? false
    }

    public init(id: Int, name: String, msgCount: Int? = 0, online: Int? = 0, isSystem: Bool? = false, isGeneral: Bool? = false, locked: Bool? = false, lockedBy: String? = nil, isOwner: Bool? = false, recommended: Bool? = false, lastMsg: LastMessage? = nil) {
        self.id = id
        self.name = name
        self.msgCount = msgCount
        self.online = online
        self.isSystem = isSystem
        self.isGeneral = isGeneral
        self.locked = locked
        self.lockedBy = lockedBy
        self.isOwner = isOwner
        self.recommended = recommended
        self.lastMsg = lastMsg
    }
}
