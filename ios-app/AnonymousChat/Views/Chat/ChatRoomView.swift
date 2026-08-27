import SwiftUI
import UniformTypeIdentifiers

public struct ChatRoomView: View {
    public let topic: Topic

    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var messageInput: String = ""
    @State private var replyingToMessage: Message?
    @State private var showOnlineSheet: Bool = false
    @State private var showDeleteTopicConfirm: Bool = false
    @State private var showMediaPicker: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var attachedBase64Images: [String] = []
    @State private var attachedVideoBase64: String?
    @State private var attachedAudioBase64: String?

    public var isTopicLocked: Bool {
        return socketManager.currentTopic?.isLocked ?? topic.isLocked
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            if isTopicLocked {
                lockedBanner
            }
            Divider().background(Color(hex: "#27272A"))
            messageListView
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if replyingToMessage != nil {
                    replyPreviewBar
                }
                if !attachedBase64Images.isEmpty || attachedVideoBase64 != nil || attachedAudioBase64 != nil {
                    attachedMediaBar
                }
                inputBar
            }
            .background(Color(hex: "#121214"))
        }
        .background(Color(hex: "#0A0A0A").ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showMediaPicker) {
            ImagePicker(
                selectedImages: $selectedImages,
                maxSelectionCount: max(1, 5 - attachedBase64Images.count),
                allowVideos: true,
                onVideoPicked: { b64 in
                    attachedVideoBase64 = b64
                }
            )
        }
        .sheet(isPresented: $showOnlineSheet) {
            OnlineMembersSheet()
        }
        .sheet(item: $socketManager.inspectedUserProfile) { userProf in
            UserProfileSheet(profile: userProf)
        }
        .onChange(of: selectedImages) { images in
            DispatchQueue.global(qos: .userInitiated).async {
                for img in images {
                    if let b64 = MediaUtils.compressImageToBase64(img) {
                        DispatchQueue.main.async {
                            if attachedBase64Images.count < 5 {
                                attachedBase64Images.append(b64)
                            }
                        }
                    }
                }
                DispatchQueue.main.async {
                    selectedImages.removeAll()
                }
            }
        }
        .onAppear {
            socketManager.joinTopic(name: topic.name)
            if topic.isGeneralTopic {
                socketManager.isGeneralActive = true
            }
        }
        .onDisappear {
            if topic.isGeneralTopic {
                socketManager.isGeneralActive = false
            }
            socketManager.leaveTopic()
            // Auto rejoin General in background to maintain live notification stream
            socketManager.joinTopic(name: "General")
        }
        .alert("Delete Topic", isPresented: $showDeleteTopicConfirm) {
            Button("Delete", role: .destructive) {
                socketManager.deleteTopic()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete this topic?")
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(topic.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    if isTopicLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                }

                Button(action: { showOnlineSheet = true }) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                        Text("\(socketManager.onlineCount) online")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#A1A1AA"))
                    }
                }
            }

            Spacer()

            Menu {
                Button(action: { showOnlineSheet = true }) {
                    Label("Online Members (\(socketManager.onlineCount))", systemImage: "person.2")
                }

                if topic.isOwnerTopic || (socketManager.myProfile?.isModerator ?? false) {
                    if isTopicLocked {
                        Button(action: { socketManager.unlockTopic() }) {
                            Label("Unlock Topic", systemImage: "lock.open")
                        }
                    } else {
                        Button(action: { socketManager.lockTopic() }) {
                            Label("Lock Topic", systemImage: "lock")
                        }
                    }

                    if !topic.isGeneralTopic && !topic.isSystemTopic {
                        Button(role: .destructive, action: { showDeleteTopicConfirm = true }) {
                            Label("Delete Topic", systemImage: "trash")
                        }
                    }
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

    private var lockedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
            Text("Topic is locked by moderator/author — viewing only")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(Color(hex: "#F59E0B"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(hex: "#78350F").opacity(0.3))
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if socketManager.hasMoreHistory {
                        Button(action: {
                            if let firstMsg = socketManager.chatMessages.first, let fId = firstMsg.msgId {
                                socketManager.loadHistory(beforeId: fId)
                            }
                        }) {
                            Text("Load older messages")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Color(hex: "#38BDF8"))
                                .padding(.vertical, 8)
                        }
                    }

                    ForEach(socketManager.chatMessages) { msg in
                        MessageBubbleView(
                            message: msg,
                            onReply: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    replyingToMessage = msg
                                }
                            },
                            onInspectUser: {
                                if let uid = msg.uid, !uid.isEmpty {
                                    socketManager.requestUserProfile(uid: uid)
                                } else if let userId = msg.userId, !userId.isEmpty {
                                    socketManager.requestUserProfile(uid: userId)
                                }
                            }
                        )
                        .id(msg.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: socketManager.chatMessages.count) { _ in
                if let last = socketManager.chatMessages.last {
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var replyPreviewBar: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color(hex: "#38BDF8"))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                if let rep = replyingToMessage {
                    Text("Replying to \(rep.authorName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#38BDF8"))
                    Text(rep.bodyText.isEmpty ? "[Media]" : rep.bodyText)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    replyingToMessage = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#71717A"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxHeight: 46)
        .background(Color(hex: "#18181B"))
        .border(Color(hex: "#27272A"), width: 0.5)
    }

    private var attachedMediaBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Photos
                ForEach(Array(attachedBase64Images.enumerated()), id: \.offset) { idx, b64 in
                    let cleanB64 = b64.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                    if let data = Data(base64Encoded: cleanB64), let uiImg = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: { attachedBase64Images.remove(at: idx) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .background(Circle().fill(Color.black))
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }

                // Video
                if attachedVideoBase64 != nil {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#18181B"))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "video.fill").foregroundColor(Color(hex: "#38BDF8")))

                        Button(action: { attachedVideoBase64 = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.black))
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                // Audio
                if attachedAudioBase64 != nil {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#18181B"))
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "music.note").foregroundColor(Color(hex: "#F59E0B")))

                        Button(action: { attachedAudioBase64 = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.black))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(hex: "#141416"))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Unified direct Gallery Picker Button (Photos & Videos)
            Button(action: {
                showMediaPicker = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(isTopicLocked ? Color(hex: "#52525B") : Color(hex: "#38BDF8"))
                    .padding(4)
            }
            .disabled(isTopicLocked)

            TextField(isTopicLocked ? "Topic is locked..." : "Message \(topic.name)...", text: $messageInput)
                .foregroundColor(.white)
                .disabled(isTopicLocked)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "#18181B"))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                )

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend && !isTopicLocked ? Color(hex: "#38BDF8") : Color(hex: "#3F3F46"))
            }
            .disabled(!canSend || isTopicLocked)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var canSend: Bool {
        let hasText = !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !attachedBase64Images.isEmpty || attachedVideoBase64 != nil || attachedAudioBase64 != nil
        return hasText || hasMedia
    }

    private func sendMessage() {
        let clean = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend && !isTopicLocked else { return }

        let imgs = attachedBase64Images.isEmpty ? nil : attachedBase64Images
        let rName = replyingToMessage?.authorName
        let rText = replyingToMessage?.bodyText
        let rId = replyingToMessage?.msgId

        socketManager.sendMessage(
            text: clean,
            images: imgs,
            video: attachedVideoBase64,
            audio: attachedAudioBase64,
            replyName: rName,
            replyText: rText,
            replyMsgId: rId
        )

        messageInput = ""
        replyingToMessage = nil
        attachedBase64Images.removeAll()
        attachedVideoBase64 = nil
        attachedAudioBase64 = nil
    }
}
