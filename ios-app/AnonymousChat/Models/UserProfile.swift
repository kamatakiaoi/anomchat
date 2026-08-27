import Foundation

public struct UserProfile: Codable, Identifiable, Equatable {
    public var id: String {
        if let u = uid, !u.isEmpty { return u }
        if let sid = userId, !sid.isEmpty { return sid }
        if let i = ip, !i.isEmpty { return i }
        if let n = name, !n.isEmpty { return n }
        return UUID().uuidString
    }

    public var uid: String?
    public var userId: String?
    public var name: String?
    public var color: String?
    public var avatar: String?
    public var ip: String?
    public var role: String?
    public var isMuted: Bool?
    public var messages: Int?
    public var media: Int?
    public var disk: String?

    public var displayName: String {
        return name ?? "Anon"
    }

    public var displayColor: String {
        return color ?? "#3B82F6,#60A5FA"
    }

    public var isModerator: Bool {
        return role == "moderator" || role == "admin"
    }

    enum CodingKeys: String, CodingKey {
        case uid
        case userId = "id"
        case name
        case color
        case avatar
        case ip
        case role
        case isMuted
        case messages
        case media
        case disk
    }

    public init(uid: String? = "", userId: String? = nil, name: String? = "Anon", color: String? = "#3B82F6,#60A5FA", avatar: String? = nil, ip: String? = "", role: String? = nil, isMuted: Bool? = nil, messages: Int? = nil, media: Int? = nil, disk: String? = nil) {
        self.uid = uid
        self.userId = userId
        self.name = name
        self.color = color
        self.avatar = avatar
        self.ip = ip
        self.role = role
        self.isMuted = isMuted
        self.messages = messages
        self.media = media
        self.disk = disk
    }
}

public struct ServerStats: Codable {
    public var online: Int
    public var totalUsers: Int
    public var totalMessages: Int
    public var totalTopics: Int
    public var totalPosts: Int
    public var uptime: String?

    public init(online: Int = 0, totalUsers: Int = 0, totalMessages: Int = 0, totalTopics: Int = 0, totalPosts: Int = 0, uptime: String? = nil) {
        self.online = online
        self.totalUsers = totalUsers
        self.totalMessages = totalMessages
        self.totalTopics = totalTopics
        self.totalPosts = totalPosts
        self.uptime = uptime
    }
}
