import SwiftUI

public struct MessageBubbleView: View, Equatable {
    public let message: Message
    public let isHighlighted: Bool
    public let onReply: () -> Void
    public let onInspectUser: () -> Void
    public var onJumpToReply: ((Int) -> Void)?
    public var onOpenMedia: ((URL, Bool) -> Void)?

    public init(
        message: Message,
        isHighlighted: Bool = false,
        onReply: @escaping () -> Void,
        onInspectUser: @escaping () -> Void,
        onJumpToReply: ((Int) -> Void)? = nil,
        onOpenMedia: ((URL, Bool) -> Void)? = nil
    ) {
        self.message = message
        self.isHighlighted = isHighlighted
        self.onReply = onReply
        self.onInspectUser = onInspectUser
        self.onJumpToReply = onJumpToReply
        self.onOpenMedia = onOpenMedia
    }

    public static func == (lhs: MessageBubbleView, rhs: MessageBubbleView) -> Bool {
        return lhs.message == rhs.message && lhs.isHighlighted == rhs.isHighlighted
    }

    private let socketManager = SocketManager.shared
    private let prefs = PreferenceManager.shared

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
        // 3. Name & Color check (fallback for legacy messages without uid)
        if let myName = socketManager.myProfile?.name, !myName.isEmpty,
           let myColor = socketManager.myProfile?.color, !myColor.isEmpty {
            if myName.lowercased() == message.authorName.lowercased() &&
               myColor == message.authorColor {
                return true
            }
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
        Button(action: {
            if let targetId = message.replyMsgId {
                onJumpToReply?(targetId)
            }
        }) {
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

                Spacer(minLength: 4)

                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelf ? Color.white.opacity(0.65) : Color(hex: "#71717A"))
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
        .buttonStyle(PlainButtonStyle())
    }

    private func bubbleContentBox(isSelf: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Attached Photos
            if !message.allImages.isEmpty {
                ForEach(message.allImages, id: \.self) { imgPath in
                    if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                        Button(action: {
                            onOpenMedia?(imgUrl, false)
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
                    onOpenMedia?(vidUrl, true)
                }
                .frame(minWidth: 220, maxWidth: 280)
            }

            // Attached Audio
            if let aud = message.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
                AudioMessageView(audioUrl: audUrl.absoluteString)
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
                .stroke(isHighlighted ? Color(hex: "#F59E0B") : (isSelf ? Color.white.opacity(0.15) : Color(hex: "#2C2C2E")), lineWidth: isHighlighted ? 2.5 : 1)
        )
        .shadow(color: isHighlighted ? Color(hex: "#F59E0B").opacity(0.8) : Color.clear, radius: isHighlighted ? 8 : 0)
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
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

public struct AudioMessageView: View {
    public let audioUrl: String
    @ObservedObject var audioPlayer = AudioPlayerManager.shared
    @State private var isScrubbing: Bool = false
    @State private var scrubValue: Double = 0

    private var isThisAudioActive: Bool {
        audioPlayer.currentPlayingUrl == audioUrl
    }

    private var displayCurrentTime: Double {
        if isScrubbing { return scrubValue }
        return isThisAudioActive ? audioPlayer.currentTime : 0
    }

    private var displayDuration: Double {
        isThisAudioActive ? max(audioPlayer.duration, 0.1) : 0.1
    }

    public var body: some View {
        let isCurPlaying = isThisAudioActive && audioPlayer.isPlaying

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Play / Pause Button
                Button(action: {
                    audioPlayer.playOrPause(urlStr: audioUrl)
                }) {
                    Image(systemName: isCurPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color(hex: "#38BDF8"))
                }
                .buttonStyle(PlainButtonStyle())

                // Quick -5s Rewind
                if isThisAudioActive && audioPlayer.duration > 0 {
                    Button(action: {
                        audioPlayer.seekRelative(-5)
                    }) {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#A1A1AA"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Interactive Scrubber Slider
                Slider(
                    value: Binding(
                        get: { displayCurrentTime },
                        set: { newVal in
                            scrubValue = newVal
                            if !isScrubbing {
                                isScrubbing = true
                            }
                            if isThisAudioActive {
                                audioPlayer.seek(toSeconds: newVal)
                            }
                        }
                    ),
                    in: 0...displayDuration,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing && isThisAudioActive {
                            audioPlayer.seek(toSeconds: scrubValue)
                        } else if editing && !isThisAudioActive {
                            audioPlayer.playOrPause(urlStr: audioUrl)
                        }
                    }
                )
                .accentColor(Color(hex: "#38BDF8"))

                // Quick +5s Forward
                if isThisAudioActive && audioPlayer.duration > 0 {
                    Button(action: {
                        audioPlayer.seekRelative(5)
                    }) {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#A1A1AA"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Duration and label Row
            HStack {
                Label("Voice Note", systemImage: "waveform")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#71717A"))

                Spacer()

                Text("\(formatTime(displayCurrentTime)) / \(formatTime(displayDuration))")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(Color(hex: "#A1A1AA"))
            }
        }
        .padding(10)
        .frame(minWidth: 230, maxWidth: 300)
        .background(Color(hex: "#141416"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite && !sec.isNaN && sec >= 0 else { return "00:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
