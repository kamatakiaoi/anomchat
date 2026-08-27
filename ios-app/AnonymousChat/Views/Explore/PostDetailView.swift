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
            headerBar
            Divider().background(Color(hex: "#27272A"))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mainPostCard
                    commentsSection
                }
                .padding(14)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomCommentBar
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
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                socketManager.deleteExplorePost(postId: currentPost.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this post?")
        }
        .onAppear {
            socketManager.getExplorePost(postId: post.id)
            socketManager.viewExplorePost(postId: post.id)
            socketManager.loadExploreComments(postId: post.id)
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
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
    }

    private var mainPostCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorRow
            titleAndBodySection
            tagsRow
            mediaSection
            postActionsBar
        }
        .padding(14)
        .background(Color(hex: "#141416"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            Button(action: {
                if let uid = currentPost.uid, !uid.isEmpty {
                    socketManager.requestUserProfile(uid: uid)
                } else if let uid = currentPost.userId, !uid.isEmpty {
                    socketManager.requestUserProfile(uid: uid)
                }
            }) {
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
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(currentPost.authorName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.white)

                Text(TimeUtils.formatMessageTime(currentPost.postTime, timezone: prefs.timezone))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#71717A"))
            }

            Spacer()
        }
    }

    private var titleAndBodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentPost.postTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            if !currentPost.postBody.isEmpty {
                FormattedMarkdownText(
                    text: currentPost.postBody,
                    fontSize: 14.5,
                    fontColor: Color(hex: "#E4E4E7")
                )
            }
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !currentPost.postTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(currentPost.postTags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#0369A1").opacity(0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        if !currentPost.allImages.isEmpty {
            VStack(spacing: 8) {
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
        }

        if let vid = currentPost.video, let vidUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: vid) {
            InlineVideoPlayerView(videoUrl: vidUrl) {
                activeLightboxUrl = vidUrl
            }
        }

        if let aud = currentPost.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
            audioPlayerBox(audUrl: audUrl)
        }
    }

    private func audioPlayerBox(audUrl: URL) -> some View {
        let isCurPlaying = AudioPlayerManager.shared.currentPlayingUrl == audUrl.absoluteString && AudioPlayerManager.shared.isPlaying
        return HStack(spacing: 8) {
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

    private var postActionsBar: some View {
        HStack(spacing: 14) {
            voteControl

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

    private var voteControl: some View {
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
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments (\(socketManager.exploreComments.count))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 6)

            if socketManager.exploreComments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#52525B"))
                    Text("No comments yet. Be the first to share your thoughts!")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#71717A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(socketManager.exploreComments) { cmt in
                        CommentRowView(
                            comment: cmt,
                            onReply: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    replyingToComment = cmt
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var bottomCommentBar: some View {
        VStack(spacing: 0) {
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
