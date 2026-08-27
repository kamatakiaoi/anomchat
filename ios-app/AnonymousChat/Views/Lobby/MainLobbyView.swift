import SwiftUI

public struct MainLobbyView: View {
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var selectedTab: Int = 0 // 0: Topics, 1: Explore
    @State private var searchText: String = ""
    @State private var showCreateSheet: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var showPatchNotes: Bool = false
    @State private var activeChatTopic: Topic?
    @State private var activePostDetail: Post?

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Header Bar
                    HStack(spacing: 12) {
                        // Ping indicator + Title
                        HStack(spacing: 8) {
                            Circle()
                                .fill(socketManager.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)

                            Text("Anonymous Chat")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Patch Notes Button
                        Button(action: { showPatchNotes = true }) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#38BDF8"))
                                .padding(8)
                                .background(Color(hex: "#18181B"))
                                .clipShape(Circle())
                        }

                        // Profile Avatar
                        Button(action: { showProfileSheet = true }) {
                            if let profile = socketManager.myProfile {
                                ZStack {
                                    Circle()
                                        .fill(ColorHelper.avatarGradient(profile.color))
                                        .frame(width: 34, height: 34)

                                    if let av = profile.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                        AsyncImage(url: avUrl) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.clear
                                        }
                                        .frame(width: 34, height: 34)
                                        .clipShape(Circle())
                                    } else {
                                        Text(String(profile.name.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#0A0A0A"))

                    // Segmented Control (Topics vs Explore)
                    HStack(spacing: 0) {
                        Button(action: { selectedTab = 0 }) {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 13))
                                    Text("Topics")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(selectedTab == 0 ? .white : Color(hex: "#71717A"))

                                Rectangle()
                                    .fill(selectedTab == 0 ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: {
                            selectedTab = 1
                            socketManager.loadExploreFeed(page: 1, sort: "hot", q: searchText)
                        }) {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari.fill")
                                        .font(.system(size: 13))
                                    Text("Explore")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(selectedTab == 1 ? .white : Color(hex: "#71717A"))

                                Rectangle()
                                    .fill(selectedTab == 1 ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                    .background(Color(hex: "#0A0A0A"))

                    Divider().background(Color(hex: "#27272A"))

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#71717A"))
                            .font(.system(size: 14))

                        TextField(selectedTab == 0 ? "Search topics..." : "Search explore posts...", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .onChange(of: searchText) { val in
                                if selectedTab == 1 {
                                    socketManager.loadExploreFeed(page: 1, sort: "hot", q: val)
                                }
                            }

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(hex: "#71717A"))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "#18181B"))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Content Area
                    if selectedTab == 0 {
                        // Topics List
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredTopics) { topic in
                                    TopicRowView(topic: topic) {
                                        activeChatTopic = topic
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 80)
                        }
                    } else {
                        // Explore Posts List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(socketManager.explorePosts) { post in
                                    ExplorePostRowView(post: post) {
                                        activePostDetail = post
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 80)
                        }
                    }

                    // Server Stats Bar at bottom
                    if let stats = socketManager.serverStats {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("\(stats.online) online")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(Color(hex: "#A1A1AA"))
                            }
                            Text("\(stats.totalMessages) msgs")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#71717A"))
                            Text("\(stats.totalTopics) topics")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#71717A"))
                            Text("\(stats.totalPosts) posts")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#71717A"))
                            Spacer()
                            Text("\(socketManager.pingMs)ms")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(Color(hex: "#38BDF8"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#121214"))
                    }
                }

                // Floating Action Button (+)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showCreateSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 54, height: 54)
                                .background(
                                    LinearGradient(colors: [Color.blue, Color(hex: "#2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Circle())
                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 36)
                    }
                }

                // In-App Notification Dropdown Banner (Messenger Style)
                if let banner = NotificationManager.shared.activeBanner {
                    VStack {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(ColorHelper.avatarGradient(banner.color))
                                    .frame(width: 38, height: 38)
                                if let av = banner.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                    AsyncImage(url: avUrl) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: { Color.clear }
                                    .frame(width: 38, height: 38)
                                    .clipShape(Circle())
                                } else {
                                    Text(String(banner.title.prefix(1)).uppercased())
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(banner.title)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.white)
                                Text(banner.body)
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color(hex: "#E4E4E7"))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: { NotificationManager.shared.dismissBanner() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#A1A1AA"))
                                    .padding(6)
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#3F3F46"), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.6), radius: 12, y: 6)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .onTapGesture {
                            NotificationManager.shared.dismissBanner()
                            if let generalTopic = socketManager.topics.first(where: { $0.name.lowercased() == "general" }) {
                                activeChatTopic = generalTopic
                            }
                        }

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateSheet) {
                if selectedTab == 0 {
                    CreateTopicSheet()
                } else {
                    CreatePostSheet()
                }
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheet()
            }
            .sheet(isPresented: $showPatchNotes) {
                PatchNotesView()
            }
            .background(
                Group {
                    if let topic = activeChatTopic {
                        NavigationLink(
                            destination: ChatRoomView(topic: topic),
                            isActive: Binding(
                                get: { activeChatTopic != nil },
                                set: { if !$0 { activeChatTopic = nil } }
                            )
                        ) { EmptyView() }
                    }

                    if let post = activePostDetail {
                        NavigationLink(
                            destination: PostDetailView(post: post),
                            isActive: Binding(
                                get: { activePostDetail != nil },
                                set: { if !$0 { activePostDetail = nil } }
                            )
                        ) { EmptyView() }
                    }
                }
            )
        }
    }

    private var filteredTopics: [Topic] {
        if searchText.isEmpty { return socketManager.topics }
        return socketManager.topics.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}
