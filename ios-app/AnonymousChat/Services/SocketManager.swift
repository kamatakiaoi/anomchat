import Foundation
import SwiftUI
import Combine

public class SocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    public static let shared = SocketManager()

    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var authTimeoutTimer: Timer?

    private var isManualDisconnect = false
    private var isConnectedInternal = false
    private var pingStartTime: Double = 0
    private var pendingAuthAction: (() -> Void)?
    private var currentConnectionId = UUID()

    @Published public var isConnected: Bool = false
    @Published public var isConnecting: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var isSubmittingPost: Bool = false
    @Published public var postCreatedSuccessfully: Bool = false
    @Published public var pingMs: Int = 0
    @Published public var myProfile: UserProfile?
    @Published public var serverStats: ServerStats?
    @Published public var topics: [Topic] = []
    @Published public var currentTopic: Topic?
    @Published public var chatMessages: [Message] = []
    @Published public var onlineMembers: [UserProfile] = []
    @Published public var onlineCount: Int = 0
    @Published public var hasMoreHistory: Bool = false

    // Explore feed state
    @Published public var explorePosts: [Post] = []
    @Published public var exploreTotalPages: Int = 1
    @Published public var exploreTotalCount: Int = 0
    @Published public var explorePage: Int = 1
    @Published public var exploreSort: String = "latest"
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

        // Hydrate from local cache immediately for 0ms initial render
        loadLocalCache()

        // Listen for app lifecycle to save battery & manage connection safely
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle Battery & Stability Optimization
    @objc public func appDidEnterBackground() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pingTimer?.invalidate()
            self.pingTimer = nil
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            self.authTimeoutTimer?.invalidate()
            self.authTimeoutTimer = nil
        }
    }

    @objc public func appWillEnterForeground() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isConnectedInternal && self.webSocketTask?.state == .running {
                self.startPingTimer()
            } else if !self.isManualDisconnect {
                self.connect()
            }
        }
    }

    // MARK: - Local Cache
    private func loadLocalCache() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "cached_topics"),
           let list = try? JSONDecoder().decode([Topic].self, from: data) {
            self.topics = list
        }
        if let data = defaults.data(forKey: "cached_explore_posts"),
           let list = try? JSONDecoder().decode([Post].self, from: data) {
            self.explorePosts = list
        }
    }

    private func saveTopicsCache(_ list: [Topic]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "cached_topics")
        }
    }

    private func saveExploreCache(_ list: [Post]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "cached_explore_posts")
        }
    }

    // MARK: - Connection Management
    public func connect(urlStr: String? = nil) {
        let base = urlStr ?? PreferenceManager.shared.serverBaseUrl
        guard let httpUrl = URL(string: base) else {
            DispatchQueue.main.async {
                self.authErrorMessage = "Invalid server URL"
                self.isConnecting = false
            }
            return
        }

        disconnect(manual: false)
        isManualDisconnect = false

        let connectionId = UUID()
        self.currentConnectionId = connectionId

        DispatchQueue.main.async {
            self.isConnecting = true
            self.authErrorMessage = nil
        }

        let host = httpUrl.host ?? "localhost"
        let port = httpUrl.port ?? (httpUrl.scheme == "https" ? 443 : 80)
        let scheme = httpUrl.scheme == "https" ? "wss" : "ws"
        let deviceMac = PreferenceManager.shared.getDeviceMac()

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if httpUrl.port != nil {
            components.port = port
        }
        components.path = "/socket.io/"
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket"),
            URLQueryItem(name: "mac", value: deviceMac)
        ]

        guard let wsUrl = components.url else { return }

        var request = URLRequest(url: wsUrl)
        request.setValue(deviceMac, forHTTPHeaderField: "x-client-mac")
        request.timeoutInterval = 10
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        listenForMessages(connectionId: connectionId)
    }

    public func disconnect(manual: Bool = true) {
        isManualDisconnect = manual
        currentConnectionId = UUID() // invalidate pending listener loops
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = nil
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil
            self.authTimeoutTimer?.invalidate()
            self.authTimeoutTimer = nil
            self.isConnected = false
            self.isConnecting = false
            self.isConnectedInternal = false
            self.isAuthenticating = false
        }
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func listenForMessages(connectionId: UUID) {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.currentConnectionId == connectionId else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleSocketIOString(text, connectionId: connectionId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleSocketIOString(text, connectionId: connectionId)
                    }
                @unknown default:
                    break
                }
                self.listenForMessages(connectionId: connectionId)
            case .failure(let error):
                guard self.currentConnectionId == connectionId else { return }
                print("WebSocket receive notice: \(error.localizedDescription)")
                self.handleDisconnect(connectionId: connectionId)
            }
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // Connected
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect(connectionId: self.currentConnectionId)
    }

    private func handleDisconnect(connectionId: UUID) {
        guard self.currentConnectionId == connectionId else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentConnectionId == connectionId else { return }
            self.isConnected = false
            self.isConnecting = false
            self.isConnectedInternal = false
            self.pingMs = 0

            if !self.isManualDisconnect {
                self.reconnectTimer?.invalidate()
                self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self = self, !self.isManualDisconnect, !self.isConnectedInternal else { return }
                    self.connect()
                }
            }
        }
    }

    private func handleSocketIOString(_ raw: String, connectionId: UUID) {
        guard self.currentConnectionId == connectionId else { return }

        // Socket.IO Engine.IO protocol parser
        if raw.hasPrefix("0") {
            // Engine.IO Handshake open packet -> send Socket.IO CONNECT
            let deviceMac = PreferenceManager.shared.getDeviceMac()
            let connectPayload = "40{\"token\":\"\",\"mac\":\"\(deviceMac)\"}"
            sendRaw(connectPayload)

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.currentConnectionId == connectionId else { return }
                self.isConnected = true
                self.isConnecting = false
                self.isConnectedInternal = true
                self.startPingTimer()

                // Execute any queued auth action
                if let pending = self.pendingAuthAction {
                    self.pendingAuthAction = nil
                    pending()
                } else if let savedKey = PreferenceManager.shared.authKey, !savedKey.isEmpty {
                    self.authKey(key: savedKey)
                }

                self.getTopics()
                self.loadExploreFeed(page: self.explorePage, sort: self.exploreSort)
            }
            return
        }

        if raw == "2" {
            // Ping from server -> reply Pong immediately
            sendRaw("3")
            return
        }

        if raw.hasPrefix("42") {
            // Socket.IO Event Packet
            let jsonString = String(raw.dropFirst(2))
            handleSocketEvent(jsonString: jsonString, connectionId: connectionId)
        }
    }

    private func handleSocketEvent(jsonString: String, connectionId: UUID) {
        guard self.currentConnectionId == connectionId else { return }
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = jsonArray.first as? String else {
            return
        }

        let payload = jsonArray.count > 1 ? jsonArray[1] : nil

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentConnectionId == connectionId else { return }

            switch eventName {
            case "pong-check":
                if self.pingStartTime > 0 {
                    self.pingMs = max(1, Int((Date().timeIntervalSince1970 * 1000) - self.pingStartTime))
                    self.pingStartTime = 0
                }

            case "profile":
                self.authTimeoutTimer?.invalidate()
                self.authTimeoutTimer = nil
                self.isAuthenticating = false
                self.authErrorMessage = nil
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let prof = try? JSONDecoder().decode(UserProfile.self, from: data) {
                    self.myProfile = prof
                    self.getTopics()
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
                    self.saveTopicsCache(topList)
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
                    if let mList = dict["members"] as? [[String: Any]] {
                        self.onlineMembers = self.parseMembersList(mList)
                    }
                    self.onlineCount = dict["topicOnline"] as? Int ?? dict["online"] as? Int ?? self.onlineMembers.count
                    self.hasMoreHistory = dict["hasMore"] as? Bool ?? false
                }

            case "topic-online":
                if let dict = payload as? [String: Any] {
                    self.onlineCount = dict["topicOnline"] as? Int ?? dict["online"] as? Int ?? 0
                    if let mList = dict["members"] as? [[String: Any]] {
                        self.onlineMembers = self.parseMembersList(mList)
                    }
                }

            case "topic-state":
                if let dict = payload as? [String: Any],
                   let tId = dict["id"] as? Int,
                   let locked = dict["locked"] as? Bool {
                    if self.currentTopic?.id == tId {
                        self.currentTopic?.locked = locked
                    }
                    if let idx = self.topics.firstIndex(where: { $0.id == tId }) {
                        self.topics[idx].locked = locked
                    }
                }

            case "topic-deleted":
                if let dict = payload as? [String: Any],
                   let tId = dict["id"] as? Int {
                    if self.currentTopic?.id == tId {
                        self.currentTopic = nil
                        self.chatMessages.removeAll()
                    }
                    self.topics.removeAll(where: { $0.id == tId })
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

                    let isSelf = (self.myProfile?.uid == msg.uid && msg.uid != nil && !(msg.uid!.isEmpty)) ||
                                 (self.myProfile?.userId == msg.userId && msg.userId != nil && !(msg.userId!.isEmpty)) ||
                                 ((self.myProfile?.displayName ?? "").lowercased() == msg.authorName.lowercased() && msg.authorName != "Anon")

                    // Replace matching optimistic temp message or append
                    if let tempIdx = self.chatMessages.firstIndex(where: {
                        ($0.msgId == 0 || $0.msgId == nil) &&
                        $0.bodyText == msg.bodyText &&
                        $0.authorName == msg.authorName
                    }) {
                        self.chatMessages[tempIdx] = msg
                    } else if !self.chatMessages.contains(where: { $0.msgId == msg.msgId && (msg.msgId ?? 0) > 0 }) {
                        self.chatMessages.append(msg)
                    }

                    // Dispatch Heads-up / Push Notification if from other users in General
                    if !isSelf {
                        NotificationManager.shared.showGeneralNotification(
                            sender: msg.authorName,
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
                    self.explorePage = dict["page"] as? Int ?? 1
                    self.exploreTotalPages = dict["totalPages"] as? Int ?? 1
                    self.exploreTotalCount = dict["totalCount"] as? Int ?? posts.count
                    self.explorePosts = posts
                    self.saveExploreCache(posts)
                }

            case "explore-created", "explore-post":
                self.isSubmittingPost = false
                self.postCreatedSuccessfully = true
                if let dict = payload as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: dict),
                   let post = try? JSONDecoder().decode(Post.self, from: data) {
                    if !self.explorePosts.contains(where: { $0.id == post.id }) {
                        self.explorePosts.insert(post, at: 0)
                        self.exploreTotalCount += 1
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
                    if let pId = cmt.postId, self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.comments = (self.currentPostDetail?.comments ?? 0) + 1
                    }
                    if let pId = cmt.postId, let idx = self.explorePosts.firstIndex(where: { $0.id == pId }) {
                        self.explorePosts[idx].comments = (self.explorePosts[idx].comments ?? 0) + 1
                    }
                }

            case "explore-comment-count":
                if let dict = payload as? [String: Any],
                   let pId = dict["id"] as? Int,
                   let comments = dict["comments"] as? Int {
                    if let idx = self.explorePosts.firstIndex(where: { $0.id == pId }) {
                        self.explorePosts[idx].comments = comments
                    }
                    if self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.comments = comments
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

            case "explore-vote-update":
                if let dict = payload as? [String: Any],
                   let pId = dict["id"] as? Int,
                   let score = dict["score"] as? Int {
                    if let idx = self.explorePosts.firstIndex(where: { $0.id == pId }) {
                        self.explorePosts[idx].score = score
                    }
                    if self.currentPostDetail?.id == pId {
                        self.currentPostDetail?.score = score
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
                self.isAuthenticating = false
                if let dict = payload as? [String: Any],
                   let rec = dict["recoveryKey"] as? String {
                    self.createdRecoveryKey = rec
                }

            case "key-recovered":
                self.isAuthenticating = false
                if let dict = payload as? [String: Any],
                   let key = dict["key"] as? String {
                    self.recoveredKey = key
                    PreferenceManager.shared.authKey = key
                }

            case "auth-error":
                self.authTimeoutTimer?.invalidate()
                self.authTimeoutTimer = nil
                self.isAuthenticating = false
                if let dict = payload as? [String: Any],
                   let msg = dict["message"] as? String {
                    self.authErrorMessage = msg
                } else if let str = payload as? String {
                    self.authErrorMessage = str
                } else {
                    self.authErrorMessage = "Invalid private key"
                }

            case "force-logout":
                PreferenceManager.shared.authKey = nil
                self.myProfile = nil
                self.errorMessage = "Logged out by administrator"

            case "error":
                self.isSubmittingPost = false
                self.isAuthenticating = false
                if let msg = payload as? String {
                    self.errorMessage = msg
                }

            default:
                break
            }
        }
    }

    private func parseMembersList(_ list: [[String: Any]]) -> [UserProfile] {
        var result: [UserProfile] = []
        for dict in list {
            let u = UserProfile(
                uid: dict["uid"] as? String ?? "",
                userId: dict["id"] as? String,
                name: dict["name"] as? String ?? "Anon",
                color: dict["color"] as? String ?? "#3B82F6,#60A5FA",
                avatar: dict["avatar"] as? String,
                ip: dict["ip"] as? String ?? "",
                role: dict["role"] as? String,
                isMuted: dict["isMuted"] as? Bool,
                messages: dict["messages"] as? Int,
                media: dict["media"] as? Int,
                disk: dict["disk"] as? String
            )
            result.append(u)
        }
        return result
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
                print("WebSocket send error: \(error.localizedDescription)")
            }
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        // 25.0 second interval for battery efficiency (matches server.js pingInterval: 25000)
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnectedInternal else { return }
            self.pingStartTime = Date().timeIntervalSince1970 * 1000
            self.emit(event: "ping-check", data: Int(self.pingStartTime))
        }
    }

    private func startAuthWatchdog() {
        authTimeoutTimer?.invalidate()
        authTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self = self, self.isAuthenticating else { return }
            self.isAuthenticating = false
            if !self.isConnected {
                self.authErrorMessage = "Cannot connect to server. Please check your internet or server settings."
            }
        }
    }

    // MARK: - High Level Actions
    public func authKey(key: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }

        PreferenceManager.shared.authKey = cleanKey
        isAuthenticating = true
        authErrorMessage = nil
        startAuthWatchdog()

        if !isConnectedInternal {
            pendingAuthAction = { [weak self] in
                self?.authKey(key: cleanKey)
            }
            connect()
            return
        }

        let mac = PreferenceManager.shared.getDeviceMac()
        emit(event: "auth-key", data: ["key": cleanKey, "mac": mac])
    }

    public func createKey(key: String) {
        let cleanKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { return }

        PreferenceManager.shared.authKey = cleanKey
        isAuthenticating = true
        authErrorMessage = nil
        startAuthWatchdog()

        if !isConnectedInternal {
            pendingAuthAction = { [weak self] in
                self?.createKey(key: cleanKey)
            }
            connect()
            return
        }

        let mac = PreferenceManager.shared.getDeviceMac()
        emit(event: "create-key", data: ["key": cleanKey, "mac": mac])
    }

    public func recoverKey(recoveryKey: String) {
        let clean = recoveryKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isAuthenticating = true
        authErrorMessage = nil
        startAuthWatchdog()

        if !isConnectedInternal {
            pendingAuthAction = { [weak self] in
                self?.recoverKey(recoveryKey: clean)
            }
            connect()
            return
        }

        let mac = PreferenceManager.shared.getDeviceMac()
        emit(event: "recover-key", data: ["recoveryKey": clean, "mac": mac])
    }

    public func logout() {
        emit(event: "logout")
        PreferenceManager.shared.authKey = nil
        myProfile = nil
        isAuthenticating = false
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
        // 1. Optimistic message insertion for instant 0ms latency
        let myProf = self.myProfile
        let optMsg = Message(
            msgId: 0,
            userId: myProf?.userId,
            uid: myProf?.uid,
            name: myProf?.displayName ?? "Anon",
            avatar: myProf?.avatar,
            color: myProf?.displayColor ?? "#3B82F6,#60A5FA",
            text: text,
            time: ISO8601DateFormatter().string(from: Date()),
            image: images?.first,
            images: images,
            video: video,
            audio: audio,
            replyName: replyName,
            replyText: replyText,
            replyMsgId: replyMsgId
        )

        DispatchQueue.main.async { [weak self] in
            self?.chatMessages.append(optMsg)
        }

        // 2. Transmit to server
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

    public func loadExploreFeed(page: Int = 1, sort: String = "latest", q: String = "") {
        self.exploreSort = sort
        self.explorePage = page
        emit(event: "explore-feed", data: ["page": page, "sort": sort, "q": q])
    }

    public func createExplorePost(title: String, body: String, tags: [String]? = nil, images: [String]? = nil, video: String? = nil, audio: String? = nil) {
        isSubmittingPost = true
        postCreatedSuccessfully = false
        var payload: [String: Any] = ["title": title, "body": body]
        if let t = tags, !t.isEmpty { payload["tags"] = t }
        if let imgs = images, !imgs.isEmpty { payload["images"] = imgs }
        if let vid = video { payload["video"] = vid }
        if let aud = audio { payload["audio"] = aud }
        emit(event: "explore-create", data: payload)
    }

    public func voteExplorePost(postId: Int, vote: Int) {
        // Optimistic 0ms UI update
        if let idx = explorePosts.firstIndex(where: { $0.id == postId }) {
            let oldVote = explorePosts[idx].currentUserVote
            let diff = vote - oldVote
            explorePosts[idx].myVote = vote
            explorePosts[idx].score = (explorePosts[idx].score ?? 0) + diff
        }
        if currentPostDetail?.id == postId {
            let oldVote = currentPostDetail?.currentUserVote ?? 0
            let diff = vote - oldVote
            currentPostDetail?.myVote = vote
            currentPostDetail?.score = (currentPostDetail?.score ?? 0) + diff
        }
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
        // Optimistic delete
        explorePosts.removeAll(where: { $0.id == postId })
        if currentPostDetail?.id == postId {
            currentPostDetail = nil
        }
        emit(event: "explore-delete", data: postId)
    }
}
