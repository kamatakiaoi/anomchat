import SwiftUI

public struct ExplorePostRowView: View {
    public let post: Post
    public let onSelect: () -> Void

    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @State private var showDeleteConfirm: Bool = false
    @State private var showToastMessage: String?
    @State private var selectedVideoUrl: URL?

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Avatar, Name, Time, 3-dots Menu
            HStack(spacing: 10) {
                Button(action: {
                    if let uid = post.uid, !uid.isEmpty {
                        socketManager.requestUserProfile(uid: uid)
                    } else if let uid = post.userId, !uid.isEmpty {
                        socketManager.requestUserProfile(uid: uid)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(ColorHelper.avatarGradient(post.authorColor))
                            .frame(width: 34, height: 34)

                        if let av = post.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                            CachedAsyncImage(url: avUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())
                        } else {
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)

                    Text(TimeUtils.formatMessageTime(post.postTime, timezone: prefs.timezone))
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

                    if post.isPostOwner || (socketManager.myProfile?.isModerator ?? false) {
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
                }
            }

            // Post Title & Snippet
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.postTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !post.postBody.isEmpty {
                        FormattedMarkdownText(
                            text: post.postBody,
                            fontSize: 13.5,
                            fontColor: Color(hex: "#A1A1AA")
                        )
                        .lineLimit(3)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Tags
            if !post.postTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.postTags, id: \.self) { tag in
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

            // Media Preview (Images, Inline Video, or Audio)
            if !post.allImages.isEmpty {
                let images = post.allImages
                ZStack(alignment: .bottomTrailing) {
                    if images.count == 1, let firstImg = images.first,
                       let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: firstImg) {
                        CachedAsyncImage(url: imgUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                        } placeholder: {
                            Color(hex: "#18181B")
                                .frame(height: 200)
                                .overlay(ProgressView().tint(.white))
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                    } else if images.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(images.prefix(2), id: \.self) { imgPath in
                                if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                                    CachedAsyncImage(url: imgUrl) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Color(hex: "#18181B")
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipped()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .cornerRadius(10)

                        Text("1/\(images.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(8)
                            .padding(8)
                    }
                }
            } else if let vid = post.video, let vidUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: vid) {
                InlineVideoPlayerView(videoUrl: vidUrl) {
                    selectedVideoUrl = vidUrl
                }
            } else if let aud = post.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
                let isCurPlaying = AudioPlayerManager.shared.currentPlayingUrl == audUrl.absoluteString && AudioPlayerManager.shared.isPlaying
                HStack(spacing: 8) {
                    Button(action: {
                        AudioPlayerManager.shared.playOrPause(urlStr: audUrl.absoluteString)
                    }) {
                        Image(systemName: isCurPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    Text("Audio Track")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(10)
                .background(Color(hex: "#1E293B"))
                .cornerRadius(10)
            }

            // Actions Row: Upvote/Downvote, Comments, Views
            HStack(spacing: 14) {
                // Vote Segment
                HStack(spacing: 6) {
                    Button(action: {
                        let cur = post.currentUserVote
                        let next = (cur == 1) ? 0 : 1
                        socketManager.voteExplorePost(postId: post.id, vote: next)
                    }) {
                        Image(systemName: post.currentUserVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                            .font(.system(size: 14))
                            .foregroundColor(post.currentUserVote == 1 ? Color(hex: "#22C55E") : Color(hex: "#71717A"))
                    }

                    Text("\(post.currentScore)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(
                            post.currentUserVote == 1 ? Color(hex: "#22C55E") :
                            post.currentUserVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#D4D4D8")
                        )

                    Button(action: {
                        let cur = post.currentUserVote
                        let next = (cur == -1) ? 0 : -1
                        socketManager.voteExplorePost(postId: post.id, vote: next)
                    }) {
                        Image(systemName: post.currentUserVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                            .font(.system(size: 14))
                            .foregroundColor(post.currentUserVote == -1 ? Color(hex: "#EF4444") : Color(hex: "#71717A"))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#1C1C1E"))
                .cornerRadius(20)

                // Comment Button
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 13))
                    Text("\(post.commentCount)")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#A1A1AA"))

                Spacer()

                // Views Counter
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                    Text("\(post.viewCount)")
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
        .fullScreenCover(item: Binding(
            get: { selectedVideoUrl != nil ? IdentifiableURL(url: selectedVideoUrl!) : nil },
            set: { if $0 == nil { selectedVideoUrl = nil } }
        )) { idUrl in
            VideoPlayerView(videoUrl: idUrl.url)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                socketManager.deleteExplorePost(postId: post.id)
            }
            Button("Cancel", role: .cancel) {}
            Text("Are you sure you want to delete this post?")
        }
    }
}
