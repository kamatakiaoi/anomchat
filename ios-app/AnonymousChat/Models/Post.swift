import Foundation

public struct Post: Codable, Identifiable {
    public var id: Int
    public var userId: String?
    public var uid: String?
    public var name: String?
    public var avatar: String?
    public var color: String?
    public var title: String?
    public var body: String?
    public var tags: [String]?
    public var images: [String]?
    public var video: String?
    public var audio: String?
    public var views: Int?
    public var shares: Int?
    public var upvotes: Int?
    public var downvotes: Int?
    public var score: Int?
    public var comments: Int?
    public var myVote: Int? // 1, -1, 0
    public var isOwner: Bool?
    public var time: String?
    public var createdAt: String?

    public var authorName: String { name ?? "Anon" }
    public var authorColor: String { color ?? "#3B82F6,#60A5FA" }
    public var postTitle: String { title ?? "" }
    public var postBody: String { body ?? "" }
    public var postTime: String { time ?? createdAt ?? "" }
    public var viewCount: Int { views ?? 0 }
    public var commentCount: Int { comments ?? 0 }
    public var currentScore: Int { score ?? 0 }
    public var currentUserVote: Int { myVote ?? 0 }
    public var isPostOwner: Bool { isOwner ?? false }

    public var allImages: [String] {
        var res: [String] = []
        if let list = images {
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
        return res
    }

    public init(id: Int, userId: String? = nil, uid: String? = nil, name: String? = "Anon", avatar: String? = nil, color: String? = "#3B82F6,#60A5FA", title: String? = "", body: String? = "", tags: [String]? = nil, images: [String]? = nil, video: String? = nil, audio: String? = nil, views: Int? = 0, shares: Int? = 0, upvotes: Int? = 0, downvotes: Int? = 0, score: Int? = 0, comments: Int? = 0, myVote: Int? = 0, isOwner: Bool? = false, time: String? = "", createdAt: String? = "") {
        self.id = id
        self.userId = userId
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.color = color
        self.title = title
        self.body = body
        self.tags = tags
        self.images = images
        self.video = video
        self.audio = audio
        self.views = views
        self.shares = shares
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.score = score
        self.comments = comments
        self.myVote = myVote
        self.isOwner = isOwner
        self.time = time
        self.createdAt = createdAt
    }
}

public struct Comment: Codable, Identifiable {
    public var id: Int
    public var postId: Int?
    public var userId: String?
    public var uid: String?
    public var name: String?
    public var avatar: String?
    public var color: String?
    public var body: String?
    public var image: String?
    public var images: [String]?
    public var parentId: Int?
    public var replyName: String?
    public var replyText: String?
    public var time: String?
    public var createdAt: String?

    public var authorName: String { name ?? "Anon" }
    public var authorColor: String { color ?? "#3B82F6,#60A5FA" }
    public var commentBody: String { body ?? "" }
    public var commentTime: String { time ?? createdAt ?? "" }

    public var allImages: [String] {
        var res: [String] = []
        if let list = images {
            for item in list { res.append(item) }
        }
        if res.isEmpty, let single = image, !single.isEmpty {
            res.append(single)
        }
        return res
    }

    public init(id: Int, postId: Int? = 0, userId: String? = nil, uid: String? = nil, name: String? = "Anon", avatar: String? = nil, color: String? = "#3B82F6,#60A5FA", body: String? = "", image: String? = nil, images: [String]? = nil, parentId: Int? = nil, replyName: String? = nil, replyText: String? = nil, time: String? = "", createdAt: String? = "") {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.color = color
        self.body = body
        self.image = image
        self.images = images
        self.parentId = parentId
        self.replyName = replyName
        self.replyText = replyText
        self.time = time
        self.createdAt = createdAt
    }
}
