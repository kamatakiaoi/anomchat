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
        if let myUid = socketManager.myProfile?.uid, !myUid.isEmpty, let msgUid = message.uid, !msgUid.isEmpty {
            return myUid == msgUid
        }
        return socketManager.myProfile?.name.lowercased() == message.name.lowercased()
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 40) }

            if !isMe {
                // Avatar Button
                Button(action: onInspectUser) {
                    ZStack {
                        Circle()
                            .fill(ColorHelper.avatarGradient(message.color))
                            .frame(width: 32, height: 32)

                        if let av = message.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                            AsyncImage(url: avUrl) { img in
                                img.resizable().scaledToFill()
                            } placeholder: { Color.clear }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Text(String(message.name.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                // Sender Name
                if !isMe {
                    Text(message.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorHelper.colorFromHex(message.color))
                }

                // Reply Quote
                if let rName = message.replyName, let rText = message.replyText, !rName.isEmpty {
                    HStack(spacing: 6) {
                        Rectangle().fill(Color.blue).frame(width: 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#38BDF8"))
                            Text(rText)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#A1A1AA"))
                                .lineLimit(1)
                        }
                    }
                    .padding(6)
                    .background(Color(hex: "#18181B"))
                    .cornerRadius(6)
                }

                // Bubble Container
                VStack(alignment: .leading, spacing: 6) {
                    // Attached Photos
                    if !message.allImages.isEmpty {
                        ForEach(message.allImages, id: \.self) { imgPath in
                            if let imgUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: imgPath) {
                                Button(action: {
                                    selectedMediaUrl = imgUrl
                                    showLightbox = true
                                }) {
                                    AsyncImage(url: imgUrl) { img in
                                        img.resizable().scaledToFit()
                                    } placeholder: {
                                        Color(hex: "#27272A")
                                    }
                                    .frame(maxHeight: 200)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }

                    // Attached Audio
                    if let aud = message.audio, let audUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: aud) {
                        HStack(spacing: 8) {
                            Button(action: {
                                AudioPlayerManager.shared.playOrPause(urlStr: audUrl.absoluteString)
                            }) {
                                Image(systemName: AudioPlayerManager.shared.currentUrl == audUrl.absoluteString && AudioPlayerManager.shared.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            Text("Voice Note")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color(hex: "#1E293B"))
                        .cornerRadius(10)
                    }

                    // Message Text
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 14.5))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMe ? Color(hex: "#2563EB") : Color(hex: "#1F1F23"))
                .cornerRadius(16)
                .contextMenu {
                    Button(action: {
                        UIPasteboard.general.string = message.text
                    }) {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }

                    Button(action: onReply) {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }

                    Button(action: onInspectUser) {
                        Label("View Profile", systemImage: "person.circle")
                    }
                }

                // Time
                Text(TimeUtils.formatMessageTime(message.time, timezone: prefs.timezone))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#71717A"))
            }

            if !isMe { Spacer(minLength: 40) }
        }
        .sheet(isPresented: $showLightbox) {
            if let u = selectedMediaUrl {
                LightboxView(mediaUrl: u)
            }
        }
    }
}
