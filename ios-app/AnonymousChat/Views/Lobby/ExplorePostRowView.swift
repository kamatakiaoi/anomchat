import SwiftUI

public struct ExplorePostRowView: View {
    public let post: Post
    public let onSelect: () -> Void

    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @State private var showDeleteConfirm: Bool = false
    @State private var showToastMessage: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Avatar, Name, Time, 3-dots Menu
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ColorHelper.avatarGradient(post.color))
                        .frame(width: 34, height: 34)

                    if let av = post.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                        AsyncImage(url: avUrl) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.clear }
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                    } else {
                        Text(String(post.name.prefix(1)).uppercased())
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)

                    Text(TimeUtils.formatMessageTime(post.time, timezone: prefs.timezone))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#71717A"))
                }

                Spacer()

                // 3-Dots Popup Menu
                Menu {
                    Button(action: {}) {
                        Label("ID: \(post.id)", systemImage: "number")
                    }.disabled(true)

                    Button(action: {
                        let url = "\(prefs.serverBaseUrl)/explore/\(post.id)"
                        UIPasteboard.general.string = url
                        socketManager.shareExplorePost(postId: post.id)
                        showToastMessage = "Link copied to clipboard"
                    }) {
                        Label("Copy Link", systemImage: "link")
                    }

                    if post.isOwner || (socketManager.myProfile?.isModerator ?? false) {
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#71717A"))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }

            // Title & Body
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    if !post.body.isEmpty {
                        Text(post.body)
                            .font(.system(size: 13.5))
                            .foregroundColor(Color(hex: "#D4D4D8"))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Media Preview (if image or video)
            if let firstImg = post.allImages.first, let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: firstImg) {
                Button(action: onSelect) {
                    AsyncImage(url: imgUrl) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: "#18181B")
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(10)
                }
            }

            // Actions Row: Upvote/Downvote, Comments, Views
            HStack(spacing: 14) {
                // Vote Segment
                HStack(spacing: 6) {
                    Button(action: {
                        let cur = post.myVote
                        let next = (cur == 1) ? 0 : 1
                        socketManager.voteExplorePost(postId: post.id, vote: next)
                    }) {
                        Image(systemName: post.myVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 13))
                            .foregroundColor(post.myVote == 1 ? Color(hex: "#22C55E") : Color(hex: "#71717A"))
                    }

                    Text("\(post.score)")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(
                            post.myVote == 1 ? Color(hex: "#22C55E") :
                            post.myVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#D4D4D8")
                        )

                    Button(action: {
                        let cur = post.myVote
                        let next = (cur == -1) ? 0 : -1
                        socketManager.voteExplorePost(postId: post.id, vote: next)
                    }) {
                        Image(systemName: post.myVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 13))
                            .foregroundColor(post.myVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#71717A"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#18181B"))
                .cornerRadius(16)

                // Comment Button
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 13))
                        Text("\(post.comments)")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#A1A1AA"))
                }

                Spacer()

                // Views Counter
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                    Text("\(post.views)")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(hex: "#52525B"))
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(hex: "#141416"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                socketManager.deleteExplorePost(postId: post.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this post and its media from server?")
        }
        .alert(showToastMessage ?? "", isPresented: Binding(
            get: { showToastMessage != nil },
            set: { if !$0 { showToastMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        }
    }
}
