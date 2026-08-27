import Foundation
import SwiftUI
import Combine

public class SocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    public static let shared = SocketManager()

    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?

    private var isManualDisconnect = false
    private var isConnectedInternal = false
    private var pingStartTime: Double = 0

    @Published public var isConnected: Bool = false
    @Published public var pingMs: Int = 0
    @Published public var myProfile: UserProfile?
    @Published public var serverStats: ServerStats?
    @Published public var topics: [Topic] = []
    @Published public var currentTopic: Topic?
    @Published public var chatMessages: [Message] = []
    @Published public var onlineMembers: [UserProfile] = []
    @Published public var onlineCount: Int = 0
    @Published public var hasMoreHistory: Bool = false
    @Published public var explorePosts: [Post] = []
    @Published public var exploreTotalPages: Int = 1
    @Published public var explorePage: Int = 1
    @Published public var exploreComments: [Comment] = []
    @Published public var currentPostDetail: Post?
    @Published public var inspectedUserProfile: UserProfile?
    @Published public var errorMessage: String?
    @Published public var authErrorMessage: String?
    @Published public var createdRecoveryKey: String?
    @Published public var recoveredKey: String?

    public var isGeneralActive: Bool = false

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }

    public func connect(urlStr: String? = nil) {
        let base = urlStr ?? PreferenceManager.shared.serverBaseUrl
        guard let httpUrl = URL(string: base) else { return }

        disconnect()
        isManualDisconnect = false

        let host = httpUrl.host ?? "localhost"
        let port = httpUrl.port != nil ? ":\(httpUrl.port!)" : ""
        let scheme = httpUrl.scheme == "https" ? "wss" : "ws"
        let deviceMac = PreferenceManager.shared.getDeviceMac()

        guard let wsUrl = URL(string: "\(scheme)://\(host)\(port)/socket.io/?EIO=4&transport=websocket&mac=\(deviceMac)") else { return }

        var request = URLRequest(url: wsUrl)
        request.timeoutInterval = 10
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        listenForMessages()
    }

    public func disconnect() {
        isManualDisconnect = true
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnectedInternal = false
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleSocketIOString(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleSocketIOString(text)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connected
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }

    private func handleDisconnect() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.isConnectedInternal = false
        }
        if !isManualDisconnect {
            reconnectTimer?.invalidate()
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.connect()
            }
        }
    }

    private func handleSocketIOString(_ raw: String) {
        // Socket.IO Engine.IO protocol parser
        if raw.hasPrefix("0") {
            // Engine.IO Handshake open packet
            sendRaw("40") // Socket.IO CONNECT packet
            DispatchQueue.main.async {
                self.isConnected = true
                self.isConnectedInternal = true
                self.startPingTimer()

                // Auto Re-Authenticate & Join General on connection
                if let savedKey = PreferenceManager.shared.authKey, !savedKey.isEmpty {
                    self.authKey(key: savedKey)
                }
            }
            return
        }

        if raw == "2" {
            // Ping from server -> reply Pong
            sendRaw("3")
            return
        }

        if raw.hasPrefix("42") {
            // Socket.IO Event Packet
            let jsonString = String(raw.dropFirst(2))
            handleSocketEvent(jsonString: jsonString)
        }
    }

    private func handleSocketEvent(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = jsonArray.first as? String else {
            return
        }

        let payload = jsonArray.count > 1 ? jsonArray[1] : nil

        DispatchQueue.main.async {
            switch eventName {
            case "pong-check":
                if self.pingStartTime > 0 {
                    self.pingMs = max(1, Int((Date().timeIntervalSince1970 * 1000) - self.pingStartTime))
                    self.pingStartTime = 0
                }

            case "profile":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let prof = try? JSONDecoder().decode(UserProfile.self, from: data) {
                    self.myProfile = prof
                    // Join General topic in background
                    self.joinTopic(name: "General")
                }

            case "stats":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let st = try? JSONDecoder().decode(ServerStats.self, from: data) {
                    self.serverStats = st
                }

            case "topics":
                if let list = payload as? [[String: Any]],
                   let data = try? JSONSerialization.data(withJSONObject: list),
                   let topList = try? JSONDecoder().decode([Topic].self, from: data) {
                    self.topics = topList
                }

            case "joined":
                if let dict = payload as? [String: Any] {
                    if let tDict = dict["topic"] as? [String: Any],
                       let tData = try? JSONSerialization.data(withJSONObject: tDict),
                       let top = try? JSONDecoder().decode(Topic.self, from: tData) {
                        self.currentTopic = top
                    }
                    if let hList = dict["history"] as? [[String: Any]],
                       let hData = try? JSONSerialization.data(withJSONObject: hList),
                       let msgs = try? JSONDecoder().decode([Message].self, from: hData) {
                        self.chatMessages = msgs
                    }
                    if let mList = dict["members"] as? [[String: Any]],
                       let mData = try? JSONSerialization.data(withJSONObject: mList),
                       let mems = try? JSONDecoder().decode([UserProfile].self, from: mData) {
                        self.onlineMembers = mems
                    }
                    self.onlineCount = dict["online"] as? Int ?? self.onlineMembers.count
                    self.hasMoreHistory = dict["hasMore"] as? Bool ?? false
                }

            case "topic-online":
                if let dict = payload as? [String: Any] {
                    self.onlineCount = dict["online"] as? Int ?? 0
                    if let mList = dict["members"] as? [[String: Any]],
                       let mData = try? JSONSerialization.data(withJSONObject: mList),
                       let mems = try? JSONDecoder().decode([UserProfile].self, from: mData) {
                        self.onlineMembers = mems
                    }
                }

            case "topic-state":
                if let dict = payload as? [String: Any],
                   let tId = dict["id"] as? Int,
                   let locked = dict["locked"] as? Bool {
                    if self.currentTopic?.id == tId {
                        self.currentTopic?.isLocked = locked
                    }
                }

            case "topic-deleted":
                if let dict = payload as? [String: Any],
                   let tId = dict["id"] as? Int {
                    if self.currentTopic?.id == tId {
                        self.currentTopic = nil
                        self.chatMessages.removeAll()
                    }
                }

            case "history-page":
                if let dict = payload as? [String: Any],
                   let hList = dict["history"] as? [[String: Any]],
                   let hData = try? JSONSerialization.data(withJSONObject: hList),
                   let msgs = try? JSONDecoder().decode([Message].self, from: hData) {
                    self.chatMessages.insert(contentsOf: msgs, at: 0)
                    self.hasMoreHistory = dict["hasMore"] as? Bool ?? false
                }

            case "message":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let msg = try? JSONDecoder().decode(Message.self, from: data) {
                    self.chatMessages.append(msg)

                    // Dispatch Heads-up / Push Notification if from other users
                    let isMe = (self.myProfile?.uid == msg.uid) || (self.myProfile?.name.lowercased() == msg.name.lowercased())
                    if !isMe {
                        NotificationManager.shared.showGeneralNotification(
                            sender: msg.name,
                            message: msg,
                            isAppActive: true,
                            isGeneralActive: self.isGeneralActive
                        )
                    }
                }

            case "explore-feed":
                if let dict = payload as? [String: Any],
                   let pList = dict["posts"] as? [[String: Any]],
                   let pData = try? JSONSerialization.data(withJSONObject: pList),
                   let posts = try? JSONDecoder().decode([Post].self, from: pData) {
                    let page = dict["page"] as? Int ?? 1
                    self.explorePage = page
                    self.exploreTotalPages = dict["totalPages"] as? Int ?? 1
                    if page == 1 {
                        self.explorePosts = posts
                    } else {
                        self.explorePosts.append(contentsOf: posts)
                    }
                }

            case "explore-get":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let post = try? JSONDecoder().decode(Post.self, from: data) {
                    self.currentPostDetail = post
                }

            case "explore-comments":
                if let dict = payload as? [String: Any],
                   let cList = dict["comments"] as? [[String: Any]],
                   let cData = try? JSONSerialization.data(withJSONObject: cList),
                   let cmts = try? JSONDecoder().decode([Comment].self, from: cData) {
                    self.exploreComments = cmts
                }

            case "explore-comment":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let cmt = try? JSONDecoder().decode(Comment.self, from: data) {
                    self.exploreComments.append(cmt)
                    if let pId = cmt.postId as Int?, self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.comments += 1
                    }
                }

            case "explore-vote-me":
                if let dict = payload as? [String: Any],
                   let pId = dict["id"] as? Int,
                   let score = dict["score"] as? Int,
                   let myVote = dict["myVote"] as? Int {
                    if let idx = self.explorePosts.firstIndex(where: { $0.id == pId }) {
                        self.explorePosts[idx].score = score
                        self.explorePosts[idx].myVote = myVote
                    }
                    if self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.score = score
                        self.currentPostDetail?.myVote = myVote
                    }
                }

            case "explore-view-update":
                if let dict = payload as? [String: Any],
                   let pId = dict["id"] as? Int,
                   let views = dict["views"] as? Int {
                    if let idx = self.explorePosts.firstIndex(where: { $0.id == pId }) {
                        self.explorePosts[idx].views = views
                    }
                    if self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.views = views
                    }
                }

            case "explore-deleted":
                if let dict = payload as? [String: Any],
                   let pId = dict["id"] as? Int {
                    self.explorePosts.removeAll(where: { $0.id == pId })
                    if self.currentPostDetail?.id == pId {
                        self.currentPostDetail = nil
                    }
                }

            case "user-profile":
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let uProf = try? JSONDecoder().decode(UserProfile.self, from: data) {
                    self.inspectedUserProfile = uProf
                }

            case "key-created":
                if let dict = payload as? [String: Any],
                   let rec = dict["recoveryKey"] as? String {
                    self.createdRecoveryKey = rec
                }

            case "key-recovered":
                if let dict = payload as? [String: Any],
                   let key = dict["key"] as? String {
                    self.recoveredKey = key
                    PreferenceManager.shared.authKey = key
                }

            case "auth-error":
                if let dict = payload as? [String: Any],
                   let msg = dict["message"] as? String {
                    self.authErrorMessage = msg
                }

            case "force-logout":
                PreferenceManager.shared.authKey = nil
                self.myProfile = nil
                self.errorMessage = "Logged out by administrator"

            case "error":
                if let msg = payload as? String {
                    self.errorMessage = msg
                }

            default:
                break
            }
        }
    }

    public func emit(event: String, data: Any) {
        let packetArray: [Any] = [event, data]
        if let jsonData = try? JSONSerialization.data(withJSONObject: packetArray),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            sendRaw("42\(jsonStr)")
        }
    }

    public func emit(event: String) {
        let packetArray: [Any] = [event]
        if let jsonData = try? JSONSerialization.data(withJSONObject: packetArray),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            sendRaw("42\(jsonStr)")
        }
    }

    private func sendRaw(_ text: String) {
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnectedInternal else { return }
            self.pingStartTime = Date().timeIntervalSince1970 * 1000
            self.emit(event: "ping-check", data: Int(self.pingStartTime))
        }
    }

    // High Level Actions
    public func authKey(key: String) {
        let mac = PreferenceManager.shared.getDeviceMac()
        emit(event: "auth-key", data: ["key": key, "mac": mac])
    }

    public func createKey(key: String) {
        let mac = PreferenceManager.shared.getDeviceMac()
        emit(event: "create-key", data: ["key": key, "mac": mac])
    }

    public func recoverKey(recoveryKey: String) {
        emit(event: "recover-key", data: ["recoveryKey": recoveryKey])
    }

    public func logout() {
        emit(event: "logout")
        PreferenceManager.shared.authKey = nil
        myProfile = nil
    }

    public func joinTopic(name: String) {
        emit(event: "join-topic", data: name)
    }

    public func leaveTopic() {
        emit(event: "leave-topic")
        currentTopic = nil
        chatMessages.removeAll()
    }

    public func getTopics() {
        emit(event: "get-topics")
    }

    public func createTopic(name: String) {
        emit(event: "create-topic", data: name)
    }

    public func lockTopic() {
        emit(event: "topic-lock")
    }

    public func unlockTopic() {
        emit(event: "topic-unlock")
    }

    public func deleteTopic() {
        emit(event: "topic-delete")
    }

    public func sendMessage(text: String, images: [String]? = nil, video: String? = nil, audio: String? = nil, replyName: String? = nil, replyText: String? = nil, replyMsgId: Int? = nil) {
        var payload: [String: Any] = ["text": text]
        if let imgs = images, !imgs.isEmpty { payload["images"] = imgs }
        if let vid = video { payload["video"] = vid }
        if let aud = audio { payload["audio"] = aud }
        if let rName = replyName { payload["replyName"] = rName }
        if let rText = replyText { payload["replyText"] = rText }
        if let rId = replyMsgId { payload["replyMsgId"] = rId }
        emit(event: "message", data: payload)
    }

    public func loadHistory(beforeId: Int) {
        emit(event: "load-history", data: ["beforeId": beforeId])
    }

    public func requestUserProfile(uid: String) {
        emit(event: "user-profile", data: ["uid": uid])
    }

    public func updateProfile(name: String?, avatarBase64: String?) {
        if let n = name { emit(event: "change-name", data: n) }
        if let a = avatarBase64 { emit(event: "change-avatar", data: a) }
    }

    public func loadExploreFeed(page: Int = 1, sort: String = "hot", q: String = "") {
        emit(event: "explore-feed", data: ["page": page, "sort": sort, "q": q])
    }

    public func createExplorePost(title: String, body: String, tags: [String]? = nil, images: [String]? = nil, video: String? = nil, audio: String? = nil) {
        var payload: [String: Any] = ["title": title, "body": body]
        if let t = tags, !t.isEmpty { payload["tags"] = t }
        if let imgs = images, !imgs.isEmpty { payload["images"] = imgs }
        if let vid = video { payload["video"] = vid }
        if let aud = audio { payload["audio"] = aud }
        emit(event: "explore-create", data: payload)
    }

    public func voteExplorePost(postId: Int, vote: Int) {
        emit(event: "explore-vote", data: ["postId": postId, "vote": vote])
    }

    public func getExplorePost(postId: Int) {
        emit(event: "explore-get", data: postId)
    }

    public func viewExplorePost(postId: Int) {
        emit(event: "explore-view", data: postId)
    }

    public func shareExplorePost(postId: Int) {
        emit(event: "explore-share", data: postId)
    }

    public func commentExplorePost(postId: Int, body: String, parentId: Int? = nil, replyName: String? = nil, replyText: String? = nil) {
        var payload: [String: Any] = ["postId": postId, "body": body]
        if let p = parentId { payload["parentId"] = p }
        if let rName = replyName { payload["replyName"] = rName }
        if let rText = replyText { payload["replyText"] = rText }
        emit(event: "explore-comment", data: payload)
    }

    public func loadExploreComments(postId: Int) {
        emit(event: "explore-comments", data: postId)
    }

    public func deleteExplorePost(postId: Int) {
        emit(event: "explore-delete", data: postId)
    }
}
