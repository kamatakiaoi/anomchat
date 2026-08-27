import Foundation

public struct Message: Codable, Identifiable, Equatable {
    public var id: String {
        if let mId = msgId, mId > 0 {
            return "\(mId)"
        }
        return "\(time ?? "")-\(name ?? "")-\(text?.prefix(20) ?? "")"
    }

    public var msgId: Int?
    public var userId: String?
    public var uid: String?
    public var name: String?
    public var avatar: String?
    public var color: String?
    public var text: String?
    public var time: String?
    public var image: String?
    public var images: [String]?
    public var video: String?
    public var audio: String?
    public var replyName: String?
    public var replyText: String?
    public var replyMsgId: Int?

    public var authorName: String { name ?? "Anon" }
    public var authorColor: String { color ?? "#3B82F6,#60A5FA" }
    public var bodyText: String { text ?? "" }
    public var messageTime: String { time ?? "" }

    public var allImages: [String] {
        var res: [String] = []
        if let list = images, !list.isEmpty {
            for item in list {
                let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    if let data = trimmed.data(using: .utf8),
                       let parsed = try? JSONDecoder().decode([String].self, from: data) {
                        res.append(contentsOf: parsed)
                    } else {
                        res.append(trimmed)
                    }
                } else if !trimmed.isEmpty {
                    res.append(trimmed)
                }
            }
        }
        if res.isEmpty, let single = image {
            let trimmed = single.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                if let data = trimmed.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode([String].self, from: data) {
                    res.append(contentsOf: parsed)
                } else {
                    res.append(trimmed)
                }
            } else if !trimmed.isEmpty {
                res.append(trimmed)
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

    public init(msgId: Int? = 0, userId: String? = nil, uid: String? = nil, name: String? = "Anon", avatar: String? = nil, color: String? = "#3B82F6,#60A5FA", text: String? = "", time: String? = "", image: String? = nil, images: [String]? = nil, video: String? = nil, audio: String? = nil, replyName: String? = nil, replyText: String? = nil, replyMsgId: Int? = nil) {
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
