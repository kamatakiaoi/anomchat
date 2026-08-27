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

    public var currentPost: Post {
        socketManager.currentPostDetail ?? post
    }

    public var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

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

                        if currentPost.isOwner || (socketManager.myProfile?.isModerator ?? false) {
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
                                        .fill(ColorHelper.avatarGradient(currentPost.color))
                                        .frame(width: 38, height: 38)

                                    if let av = currentPost.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                        AsyncImage(url: avUrl) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: { Color.clear }
                                        .frame(width: 38, height: 38)
                                        .clipShape(Circle())
                                    } else {
                                        Text(String(currentPost.name.prefix(1)).uppercased())
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currentPost.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text(TimeUtils.formatMessageTime(currentPost.time, timezone: prefs.timezone))
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color(hex: "#71717A"))
                                }

                                Spacer()
                            }

                            // Post Title
                            Text(currentPost.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            // Post Body
                            if !currentPost.body.isEmpty {
                                Text(currentPost.body)
                                    .font(.system(size: 14.5))
                                    .foregroundColor(Color(hex: "#E4E4E7"))
                            }

                            // Photos
                            if !currentPost.allImages.isEmpty {
                                ForEach(currentPost.allImages, id: \.self) { imgPath in
                                    if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                                        AsyncImage(url: imgUrl) { img in
                                            img.resizable().scaledToFit()
                                        } placeholder: {
                                            Color(hex: "#18181B")
                                        }
                                        .cornerRadius(10)
                                    }
                                }
                            }

                            // Actions Row
                            HStack(spacing: 14) {
                                // Upvote / Downvote
                                HStack(spacing: 6) {
                                    Button(action: {
                                        let cur = currentPost.myVote
                                        let next = (cur == 1) ? 0 : 1
                                        socketManager.voteExplorePost(postId: currentPost.id, vote: next)
                                    }) {
                                        Image(systemName: currentPost.myVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                                            .font(.system(size: 13))
                                            .foregroundColor(currentPost.myVote == 1 ? Color(hex: "#22C55E") : Color(hex: "#71717A"))
                                    }

                                    Text("\(currentPost.score)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(
                                            currentPost.myVote == 1 ? Color(hex: "#22C55E") :
                                            currentPost.myVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#D4D4D8")
                                        )

                                    Button(action: {
                                        let cur = currentPost.myVote
                                        let next = (cur == -1) ? 0 : -1
                                        socketManager.voteExplorePost(postId: currentPost.id, vote: next)
                                    }) {
                                        Image(systemName: currentPost.myVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                            .font(.system(size: 13))
                                            .foregroundColor(currentPost.myVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#71717A"))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(16)

                                HStack(spacing: 4) {
                                    Image(systemName: "bubble.left")
                                        .font(.system(size: 13))
                                    Text("\(currentPost.comments)")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Color(hex: "#A1A1AA"))

                                Spacer()

                                HStack(spacing: 4) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 12))
                                    Text("\(currentPost.views) views")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Color(hex: "#52525B"))
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "#141416"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#27272A"), lineWidth: 1)
                        )

                        // Comments Section Header
                        Text("Comments (\(socketManager.exploreComments.count))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 6)

                        // Comments List
                        LazyVStack(spacing: 10) {
                            if socketManager.exploreComments.isEmpty {
                                Text("No comments yet. Be the first to comment!")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#71717A"))
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(socketManager.exploreComments) { cmt in
                                    CommentRowView(comment: cmt) {
                                        replyingToComment = cmt
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                // Replying to Comment Bar
                if let rep = replyingToComment {
                    HStack(spacing: 8) {
                        Rectangle().fill(Color.blue).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to \(rep.name)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#38BDF8"))
                            Text(rep.body)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#A1A1AA"))
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: { replyingToComment = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#71717A"))
                        }
                    }
                    .padding(8)
                    .background(Color(hex: "#18181B"))
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
                            .foregroundColor(!commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.blue : Color(hex: "#3F3F46"))
                    }
                    .disabled(commentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#121214"))
            }
        }
        .navigationBarHidden(true)
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

    private func submitComment() {
        let clean = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let parentId = replyingToComment?.id
        let rName = replyingToComment?.name
        let rText = replyingToComment?.body

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

public struct CommentRowView: View {
    public let comment: Comment
    public let onReply: () -> Void

    @ObservedObject var prefs = PreferenceManager.shared

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(ColorHelper.avatarGradient(comment.color))
                    .frame(width: 32, height: 32)

                if let av = comment.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                    AsyncImage(url: avUrl) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Text(String(comment.name.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(TimeUtils.formatMessageTime(comment.time, timezone: prefs.timezone))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#71717A"))
                }

                if let rName = comment.replyName, let rText = comment.replyText, !rName.isEmpty {
                    Text("Replying to @\(rName): \(rText)")
                        .font(.system(size: 11.5))
                        .foregroundColor(Color(hex: "#38BDF8"))
                        .lineLimit(1)
                }

                Text(comment.body)
                    .font(.system(size: 13.5))
                    .foregroundColor(Color(hex: "#E4E4E7"))

                Button(action: onReply) {
                    Text("Reply")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#38BDF8"))
                        .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(Color(hex: "#141416"))
        .cornerRadius(10)
    }
}
