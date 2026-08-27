import Foundation

public struct Message: Codable, Identifiable {
    public var id: String { "\(msgId)" }
    public var msgId: Int
    public var userId: String?
    public var uid: String?
    public var name: String
    public var avatar: String?
    public var color: String
    public var text: String
    public var time: String
    public var image: String?
    public var images: [String]?
    public var video: String?
    public var audio: String?
    public var replyName: String?
    public var replyText: String?
    public var replyMsgId: Int?

    // Local UI grouping states
    public var isGrouped: Bool = false
    public var showTime: Bool = true
    public var groupPosition: String = "g-only" // "g-top", "g-mid", "g-bot", "g-only"

    public var allImages: [String] {
        var res: [String] = []
        if let list = images, !list.isEmpty {
            for item in list {
                if item.hasPrefix("[") && item.hasSuffix("]") {
                    if let data = item.data(using: .utf8),
                       let parsed = try? JSONDecoder().decode([String].self, from: data) {
                        res.append(contentsOf: parsed)
                    } else {
                        res.append(item)
                    }
                } else {
                    res.append(item)
                }
            }
        }
        if res.isEmpty, let single = image, !single.isEmpty {
            if single.hasPrefix("[") && single.hasSuffix("]") {
                if let data = single.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode([String].self, from: data) {
                    res.append(contentsOf: parsed)
                } else {
                    res.append(single)
                }
            } else {
                res.append(single)
            }
        }
        return res
    }

    enum CodingKeys: String, CodingKey {
        case msgId
        case userId = "id"
        case uid
        case name
        case avatar
        case color
        case text
        case time
        case image
        case images
        case video
        case audio
        case replyName
        case replyText
        case replyMsgId
    }

    public init(msgId: Int, userId: String? = nil, uid: String? = nil, name: String = "Anon", avatar: String? = nil, color: String = "#3B82F6,#60A5FA", text: String = "", time: String = "", image: String? = nil, images: [String]? = nil, video: String? = nil, audio: String? = nil, replyName: String? = nil, replyText: String? = nil, replyMsgId: Int? = nil) {
        self.msgId = msgId
        self.userId = userId
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.color = color
        self.text = text
        self.time = time
        self.image = image
        self.images = images
        self.video = video
        self.audio = audio
        self.replyName = replyName
        self.replyText = replyText
        self.replyMsgId = replyMsgId
    }
}
