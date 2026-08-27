import SwiftUI

public struct PostDetailView: View {
    public let post: Post

    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var commentInput: String = ""
    @State private var replyingToComment: Comment?
    @State private var showDeleteConfirm: Bool = false
    @State private var showToastMessage: String?
    @State private var activeLightboxUrl: URL?

    public var currentPost: Post {
        socketManager.currentPostDetail ?? post
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Custom Header
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                }

                Text("Post & Comments")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // 3-Dots Top Menu
                Menu {
                    Button(action: {}) {
                        Label("ID: \(currentPost.id)", systemImage: "number")
                    }.disabled(true)

                    Button(action: {
                        let url = "\(prefs.serverBaseUrl)/explore/\(currentPost.id)"
                        UIPasteboard.general.string = url
                        socketManager.shareExplorePost(postId: currentPost.id)
                        showToastMessage = "Link copied to clipboard"
                    }) {
                        Label("Copy Link", systemImage: "link")
                    }

                    if currentPost.isPostOwner || (socketManager.myProfile?.isModerator ?? false) {
                        Button(role: .destructive, action: {
                            showDeleteConfirm = true
                        }) {
                            Label("Delete Post", systemImage: "trash")
                        }
                    }

                    Button(action: {
                        showToastMessage = "Report submitted"
                    }) {
                        Label("Report", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(hex: "#121214"))

            Divider().background(Color(hex: "#27272A"))

            // Scrollable Content (Main Post Card + Threaded Comments)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Main Post Card
                    VStack(alignment: .leading, spacing: 12) {
                        // Author Header
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(ColorHelper.avatarGradient(currentPost.authorColor))
                                    .frame(width: 38, height: 38)

                                if let av = currentPost.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                    CachedAsyncImage(url: avUrl) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: 38, height: 38)
                                    .clipShape(Circle())
                                } else {
                                    Text(String(currentPost.authorName.prefix(1)).uppercased())
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(currentPost.authorName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(TimeUtils.formatMessageTime(currentPost.postTime, timezone: prefs.timezone))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Color(hex: "#71717A"))
                            }

                            Spacer()
                        }

                        // Post Title
                        Text(currentPost.postTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        // Post Body (Markdown)
                        if !currentPost.postBody.isEmpty {
                            FormattedMarkdownText(
                                text: currentPost.postBody,
                                fontSize: 14.5,
                                fontColor: Color(hex: "#E4E4E7")
                            )
                        }

                        // Tags
                        if let tags = currentPost.tags, !tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(hex: "#38BDF8"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.15))
                                        .cornerRadius(6)
                                }
                            }
                        }

                        // Attached Images
                        if !currentPost.allImages.isEmpty {
                            ForEach(currentPost.allImages, id: \.self) { imgPath in
                                if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                                    Button(action: { activeLightboxUrl = imgUrl }) {
                                        CachedAsyncImage(url: imgUrl) { image in
                                            image.resizable().scaledToFit()
                                        } placeholder: {
                                            Color(hex: "#18181B").frame(height: 200)
                                        }
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }

                        // Attached Video (Inline Player with Fullscreen expand)
                        if let vid = currentPost.video, let vidUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: vid) {
                            InlineVideoPlayerView(videoUrl: vidUrl) {
                                activeLightboxUrl = vidUrl
                            }
                        }

                        // Attached Audio
                        if let aud = currentPost.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
                            let isCurPlaying = AudioPlayerManager.shared.currentPlayingUrl == audUrl.absoluteString && AudioPlayerManager.shared.isPlaying
                            HStack(spacing: 8) {
                                Button(action: {
                                    AudioPlayerManager.shared.playOrPause(urlStr: audUrl.absoluteString)
                                }) {
                                    Image(systemName: isCurPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                }
                                Text("Audio Track")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color(hex: "#141416"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#27272A"), lineWidth: 1)
                            )
                        }

                        // Actions Row: Upvote/Downvote, Comment Count, Views
                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Button(action: {
                                    let cur = currentPost.currentUserVote
                                    let next = (cur == 1) ? 0 : 1
                                    socketManager.voteExplorePost(postId: currentPost.id, vote: next)
                                }) {
                                    Image(systemName: currentPost.currentUserVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                                        .font(.system(size: 14))
                                        .foregroundColor(currentPost.currentUserVote == 1 ? Color(hex: "#22C55E") : Color(hex: "#71717A"))
                                }

                                Text("\(currentPost.currentScore)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(
                                        currentPost.currentUserVote == 1 ? Color(hex: "#22C55E") :
                                        currentPost.currentUserVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#D4D4D8")
                                    )

                                Button(action: {
                                    let cur = currentPost.currentUserVote
                                    let next = (cur == -1) ? 0 : -1
                                    socketManager.voteExplorePost(postId: currentPost.id, vote: next)
                                }) {
                                    Image(systemName: currentPost.currentUserVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                        .font(.system(size: 14))
                                        .foregroundColor(currentPost.currentUserVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#71717A"))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(16)

                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                        .font(.system(size: 13))
                                Text("\(currentPost.commentCount) comments")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "#A1A1AA"))

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "eye")
                                    .font(.system(size: 12))
                                Text("\(currentPost.viewCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color(hex: "#52525B"))
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(Color(hex: "#141416"))
                    .cornerRadius(14)

                    // Comments Header
                    Text("Comments (\(socketManager.exploreComments.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)

                    // Threaded Nested Comments List
                    if socketManager.exploreComments.isEmpty {
                        Text("No comments yet. Be the first to share your thoughts!")
                            .font(.system(size: 13.5))
                            .foregroundColor(Color(hex: "#71717A"))
                            .padding(14)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(organizedComments) { cmt in
                                CommentRowView(comment: cmt, onReply: {
                                    replyingToComment = cmt
                                })
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                // Replying Bar
                if let rep = replyingToComment {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color(hex: "#38BDF8"))
                            .frame(width: 3, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to \(rep.authorName)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#38BDF8"))
                            Text(rep.commentBody.isEmpty ? "[Media]" : rep.commentBody)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#A1A1AA"))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                replyingToComment = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#71717A"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxHeight: 46)
                    .background(Color(hex: "#18181B"))
                    .border(Color(hex: "#27272A"), width: 0.5)
                }

                // Comment Input Bar
                HStack(spacing: 8) {
                    TextField("Write a comment...", text: $commentInput)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "#27272A"), lineWidth: 1)
                        )

                    Button(action: submitComment) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(!commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(hex: "#38BDF8") : Color(hex: "#3F3F46"))
                    }
                    .disabled(commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#121214"))
            }
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $socketManager.inspectedUserProfile) { userProf in
            UserProfileSheet(profile: userProf)
        }
        .fullScreenCover(item: Binding(
            get: { activeLightboxUrl != nil ? IdentifiableURL(url: activeLightboxUrl!) : nil },
            set: { if $0 == nil { activeLightboxUrl = nil } }
        )) { idUrl in
            LightboxView(mediaUrl: idUrl.url)
        }
        .onAppear {
            socketManager.getExplorePost(postId: post.id)
            socketManager.viewExplorePost(postId: post.id)
            socketManager.loadExploreComments(postId: post.id)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                socketManager.deleteExplorePost(postId: post.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this post and all its attachments permanently?")
        }
        .alert(showToastMessage ?? "", isPresented: Binding(
            get: { showToastMessage != nil },
            set: { if !$0 { showToastMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
    }

    private var organizedComments: [Comment] {
        var roots: [Comment] = []
        var repliesMap: [Int: [Comment]] = [:]
        for c in socketManager.exploreComments {
            if let pId = c.parentId, pId > 0 {
                repliesMap[pId, default: []].append(c)
            } else {
                roots.append(c)
            }
        }
        var result: [Comment] = []
        for root in roots {
            result.append(root)
            if let reps = repliesMap[root.id] {
                result.append(contentsOf: reps)
            }
        }
        for (pId, reps) in repliesMap where !roots.contains(where: { $0.id == pId }) {
            result.append(contentsOf: reps)
        }
        return result
    }

    private func submitComment() {
        let clean = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let parentId = replyingToComment?.id
        let rName = replyingToComment?.authorName
        let rText = replyingToComment?.commentBody

        socketManager.commentExplorePost(
            postId: currentPost.id,
            body: clean,
            parentId: parentId,
            replyName: rName,
            replyText: rText
        )

        commentInput = ""
        replyingToComment = nil
    }
}
