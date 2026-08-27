import SwiftUI

public struct MessageBubbleView: View {
    public let message: Message
    public let onReply: () -> Void
    public let onInspectUser: () -> Void

    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @State private var showLightbox: Bool = false
    @State private var selectedMediaUrl: URL?

    public var isMe: Bool {
        // 1. Persistent Account UID check (most reliable across reloads and multi-devices)
        if let myUid = socketManager.myProfile?.uid, !myUid.isEmpty,
           let msgUid = message.uid, !msgUid.isEmpty {
            return myUid == msgUid
        }
        // 2. Active Session Socket ID / user_id check
        if let myId = socketManager.myProfile?.userId, !myId.isEmpty,
           let msgId = message.userId, !msgId.isEmpty {
            return myId == msgId
        }
        // 3. Name check (fallback when name is customized and not default Anon)
        if let myName = socketManager.myProfile?.name, !myName.isEmpty,
           myName.lowercased() != "anon",
           myName.lowercased() == message.authorName.lowercased() {
            return true
        }
        return false
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe {
                // RIGHT ALIGNED for Self Message (Me)
                Spacer(minLength: 44)
                VStack(alignment: .trailing, spacing: 3) {
                    // Self Message Header: subtle timestamp
                    HStack(spacing: 4) {
                        Text(TimeUtils.formatMessageTime(message.messageTime, timezone: prefs.timezone))
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#71717A"))
                    }

                    // Reply Quote Box if replying
                    if let rName = message.replyName, let rText = message.replyText, !rName.isEmpty {
                        replyQuoteBox(replyName: rName, replyText: rText, isSelf: true)
                    }

                    // Bubble Box (iOS Accent Blue for Me)
                    bubbleContentBox(isSelf: true)
                }
            } else {
                // LEFT ALIGNED for Other Users
                avatarButton

                VStack(alignment: .leading, spacing: 3) {
                    // Header: Author Name + Timestamp
                    HStack(spacing: 6) {
                        Text(message.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        Text(TimeUtils.formatMessageTime(message.messageTime, timezone: prefs.timezone))
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#71717A"))
                    }

                    // Reply Quote Box if replying
                    if let rName = message.replyName, let rText = message.replyText, !rName.isEmpty {
                        replyQuoteBox(replyName: rName, replyText: rText, isSelf: false)
                    }

                    // Bubble Box (Dark Neutral for Others)
                    bubbleContentBox(isSelf: false)
                }

                Spacer(minLength: 44)
            }
        }
        .padding(.vertical, 3)
        .fullScreenCover(isPresented: $showLightbox) {
            if let u = selectedMediaUrl {
                LightboxView(mediaUrl: u)
            }
        }
    }

    // MARK: - Subviews

    private var avatarButton: some View {
        Button(action: onInspectUser) {
            ZStack {
                Circle()
                    .fill(ColorHelper.avatarGradient(message.authorColor))
                    .frame(width: 34, height: 34)

                if let av = message.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                    CachedAsyncImage(url: avUrl) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                } else {
                    Text(String(message.authorName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle().stroke(Color(hex: "#27272A"), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func replyQuoteBox(replyName: String, replyText: String, isSelf: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(isSelf ? Color.white.opacity(0.8) : Color(hex: "#38BDF8"))
                .frame(width: 2.5, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(replyName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelf ? .white : Color(hex: "#38BDF8"))
                    .lineLimit(1)
                Text(replyText.isEmpty ? "[Media]" : replyText)
                    .font(.system(size: 11))
                    .foregroundColor(isSelf ? Color.white.opacity(0.85) : Color(hex: "#A1A1AA"))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelf ? Color.white.opacity(0.12) : Color(hex: "#141416"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelf ? Color.white.opacity(0.2) : Color(hex: "#27272A"), lineWidth: 0.5)
        )
    }

    private func bubbleContentBox(isSelf: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Attached Photos
            if !message.allImages.isEmpty {
                ForEach(message.allImages, id: \.self) { imgPath in
                    if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                        Button(action: {
                            selectedMediaUrl = imgUrl
                            showLightbox = true
                        }) {
                            CachedAsyncImage(url: imgUrl) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 240)
                                    .cornerRadius(10)
                            } placeholder: {
                                ZStack {
                                    Color(hex: "#18181B")
                                        .frame(width: 140, height: 100)
                                        .cornerRadius(10)
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                    }
                }
            }

            // Attached Video (Inline Player with Fullscreen expand)
            if let vid = message.video, let vidUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: vid) {
                InlineVideoPlayerView(videoUrl: vidUrl) {
                    selectedMediaUrl = vidUrl
                    showLightbox = true
                }
                .frame(minWidth: 220, maxWidth: 280)
            }

            // Attached Audio
            if let aud = message.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
                let isCurPlaying = AudioPlayerManager.shared.currentPlayingUrl == audUrl.absoluteString && AudioPlayerManager.shared.isPlaying
                HStack(spacing: 8) {
                    Button(action: {
                        AudioPlayerManager.shared.playOrPause(urlStr: audUrl.absoluteString)
                    }) {
                        Image(systemName: isCurPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    Text("Voice Note")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color(hex: "#141416"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                )
            }

            // Message Text: Never truncated, full markdown rendering
            if !message.bodyText.isEmpty {
                FormattedMarkdownText(
                    text: message.bodyText,
                    fontSize: 14.5,
                    fontColor: .white
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Group {
                if isSelf {
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#007AFF"), Color(hex: "#0062E0")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(hex: "#1C1C1E")
                }
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelf ? Color.white.opacity(0.15) : Color(hex: "#2C2C2E"), lineWidth: 1)
        )
        .contextMenu {
            if !message.bodyText.isEmpty {
                Button(action: {
                    UIPasteboard.general.string = message.bodyText
                }) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                }
            }

            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Button(action: onInspectUser) {
                Label("View Profile", systemImage: "person.circle")
            }
        }
    }
}
