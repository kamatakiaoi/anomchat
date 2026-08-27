import SwiftUI

public struct MainLobbyView: View {
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @ObservedObject var notifManager = NotificationManager.shared

    @State private var selectedTab: Int = 0 // 0: Topics, 1: Explore
    @State private var searchText: String = ""
    @State private var showCreateSheet: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var showPatchNotes: Bool = false
    @State private var showServerSheet: Bool = false

    // Topics pagination state
    @State private var topicsPage: Int = 1
    private let topicsPerPage: Int = 10

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar
                    tabSwitcher
                    Divider().background(Color(hex: "#27272A"))
                    searchBar

                    if selectedTab == 0 {
                        topicsContentView
                    } else {
                        exploreContentView
                    }

                    serverStatsFooter
                }
                .frame(maxWidth: 800) // Optimal centered layout for iPad and large screens

                // Hidden Navigation Link triggered by tapping in-app/system notification
                if let general = socketManager.topics.first(where: { $0.isGeneralTopic }) {
                    NavigationLink(
                        destination: ChatRoomView(topic: general),
                        isActive: $notifManager.shouldNavigateToGeneral
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }

                floatingAddButton
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
            .sheet(isPresented: $showServerSheet) {
                ServerConfigSheet()
            }
            .sheet(item: $socketManager.inspectedUserProfile) { userProf in
                UserProfileSheet(profile: userProf)
            }
            .onAppear {
                // Ensure General topic stream is active when in lobby for real-time notifications
                if socketManager.currentTopic == nil {
                    socketManager.joinTopic(name: "General")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(socketManager.isConnected ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                    .frame(width: 8, height: 8)

                Text("Anonymous Chat")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Server Config
            Button(action: { showServerSheet = true }) {
                Image(systemName: "server.rack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#A1A1AA"))
                    .padding(8)
                    .background(Color(hex: "#18181B"))
                    .clipShape(Circle())
            }

            // Patch Notes
            Button(action: { showPatchNotes = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#38BDF8"))
                    .padding(8)
                    .background(Color(hex: "#18181B"))
                    .clipShape(Circle())
            }

            // Profile Button
            Button(action: { showProfileSheet = true }) {
                if let profile = socketManager.myProfile {
                    ZStack {
                        Circle()
                            .fill(ColorHelper.avatarGradient(profile.color))
                            .frame(width: 34, height: 34)

                        if let av = profile.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                            CachedAsyncImage(url: avUrl) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                        } else {
                            Text(String(profile.displayName.prefix(1)).uppercased())
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
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = 0 }
            }) {
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                    socketManager.loadExploreFeed(page: 1, sort: socketManager.exploreSort, q: searchText)
                }
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
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#71717A"))
                    .font(.system(size: 14))

                TextField(selectedTab == 0 ? "Search topics..." : "Search explore posts...", text: $searchText)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .onChange(of: searchText) { val in
                        if selectedTab == 1 {
                            socketManager.loadExploreFeed(page: 1, sort: socketManager.exploreSort, q: val)
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

            // Explore Sort Filters (Latest, Hot, Oldest)
            if selectedTab == 1 {
                HStack(spacing: 8) {
                    Text("Sort:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#71717A"))

                    sortButton(title: "Latest", sortKey: "latest")
                    sortButton(title: "Hot", sortKey: "hot")
                    sortButton(title: "Oldest", sortKey: "oldest")

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func sortButton(title: String, sortKey: String) -> some View {
        let isSelected = socketManager.exploreSort == sortKey
        return Button(action: {
            socketManager.loadExploreFeed(page: 1, sort: sortKey, q: searchText)
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#A1A1AA"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue : Color(hex: "#18181B"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color(hex: "#27272A"), lineWidth: 1)
                )
        }
    }

    // MARK: - Topics View with Pagination (10 per page)

    private var topicsContentView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Pinned System Topics (Always on top)
                ForEach(systemTopics) { topic in
                    if topic.name.lowercased() == "patch notes" {
                        Button(action: { showPatchNotes = true }) {
                            TopicRowView(topic: topic, onSelect: { showPatchNotes = true })
                        }
                    } else {
                        NavigationLink(destination: ChatRoomView(topic: topic)) {
                            TopicRowView(topic: topic, onSelect: {})
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Paginated User Topics
                ForEach(currentPageUserTopics) { topic in
                    NavigationLink(destination: ChatRoomView(topic: topic)) {
                        TopicRowView(topic: topic, onSelect: {})
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Topics Pager Controls
                if totalTopicsPages > 1 {
                    HStack {
                        Button(action: {
                            if topicsPage > 1 {
                                withAnimation { topicsPage -= 1 }
                            }
                        }) {
                            Text("← Prev")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(topicsPage > 1 ? .white : Color(hex: "#52525B"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                        }
                        .disabled(topicsPage <= 1)

                        Spacer()

                        Text("\(topicsPage) / \(totalTopicsPages)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        Spacer()

                        Button(action: {
                            if topicsPage < totalTopicsPages {
                                withAnimation { topicsPage += 1 }
                            }
                        }) {
                            Text("Next →")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(topicsPage < totalTopicsPages ? .white : Color(hex: "#52525B"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                        }
                        .disabled(topicsPage >= totalTopicsPages)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .refreshable {
            socketManager.getTopics()
        }
    }

    private var systemTopics: [Topic] {
        socketManager.topics.filter { $0.isSystemTopic || $0.isGeneralTopic }
    }

    private var filteredUserTopics: [Topic] {
        let userTopics = socketManager.topics.filter { !($0.isSystemTopic || $0.isGeneralTopic) }
        if searchText.isEmpty { return userTopics }
        return userTopics.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var totalTopicsPages: Int {
        max(1, Int(ceil(Double(filteredUserTopics.count) / Double(topicsPerPage))))
    }

    private var currentPageUserTopics: [Topic] {
        let list = filteredUserTopics
        let start = (topicsPage - 1) * topicsPerPage
        if start >= list.count { return [] }
        let end = min(start + topicsPerPage, list.count)
        return Array(list[start..<end])
    }

    // MARK: - Explore View with Numbered Pagination

    private var exploreContentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if socketManager.explorePosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "safari")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#52525B"))
                        Text("No explore posts found")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#71717A"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(socketManager.explorePosts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            ExplorePostRowView(post: post, onSelect: {})
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Explore Numbered Pagination (1, 2, 3...)
                    if socketManager.exploreTotalPages > 1 {
                        exploreNumberedPaginationView
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .refreshable {
            socketManager.loadExploreFeed(page: 1, sort: socketManager.exploreSort, q: searchText)
        }
    }

    private var exploreNumberedPaginationView: some View {
        HStack(spacing: 6) {
            // Prev Button
            if socketManager.explorePage > 1 {
                Button(action: {
                    socketManager.loadExploreFeed(page: socketManager.explorePage - 1, sort: socketManager.exploreSort, q: searchText)
                }) {
                    Text("‹ Prev")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(8)
                }
            }

            // Page numbers
            HStack(spacing: 4) {
                let total = socketManager.exploreTotalPages
                let current = socketManager.explorePage
                let pages = generatePaginationNumbers(current: current, total: total)

                ForEach(Array(pages.enumerated()), id: \.offset) { _, p in
                    if p == "..." {
                        Text("...")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#71717A"))
                            .frame(width: 28, height: 32)
                    } else if let num = Int(p) {
                        Button(action: {
                            if num != current {
                                socketManager.loadExploreFeed(page: num, sort: socketManager.exploreSort, q: searchText)
                            }
                        }) {
                            Text("\(num)")
                                .font(.system(size: 13, weight: num == current ? .bold : .medium))
                                .foregroundColor(num == current ? Color(hex: "#F59E0B") : Color(hex: "#A1A1AA"))
                                .frame(width: 32, height: 32)
                                .background(num == current ? Color(hex: "#27272A") : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(2)
            .background(Color(hex: "#141416"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#27272A"), lineWidth: 1))

            // Next Button
            if socketManager.explorePage < socketManager.exploreTotalPages {
                Button(action: {
                    socketManager.loadExploreFeed(page: socketManager.explorePage + 1, sort: socketManager.exploreSort, q: searchText)
                }) {
                    Text("Next ›")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 16)
    }

    private func generatePaginationNumbers(current: Int, total: Int) -> [String] {
        if total <= 7 {
            return (1...total).map { "\($0)" }
        }
        var pages: [String] = ["1"]
        if current > 3 {
            pages.append("...")
        }
        let start = max(2, current - 1)
        let end = min(total - 1, current + 1)
        for i in start...end {
            pages.append("\(i)")
        }
        if current < total - 2 {
            pages.append("...")
        }
        pages.append("\(total)")
        return pages
    }

    // MARK: - Footer & Overlays

    private var serverStatsFooter: some View {
        HStack(spacing: 14) {
            if let stats = socketManager.serverStats {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
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
            }

            Spacer()

            Text("\(socketManager.pingMs)ms")
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundColor(socketManager.pingMs < 80 ? Color(hex: "#22C55E") : Color(hex: "#F59E0B"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(hex: "#121214"))
    }

    private var floatingAddButton: some View {
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
    }
}
