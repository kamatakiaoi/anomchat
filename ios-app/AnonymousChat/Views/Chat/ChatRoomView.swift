import SwiftUI
import PhotosUI

public struct ChatRoomView: View {
    public let topic: Topic

    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var messageInput: String = ""
    @State private var replyingToMessage: Message?
    @State private var showOnlineSheet: Bool = false
    @State private var showDeleteTopicConfirm: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedBase64Images: [String] = []

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

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(topic.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            if socketManager.currentTopic?.isLocked ?? topic.isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#EF4444"))
                            }
                        }

                        Button(action: { showOnlineSheet = true }) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("\(socketManager.onlineCount) online")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#A1A1AA"))
                            }
                        }
                    }

                    Spacer()

                    // Topic Options Menu
                    Menu {
                        Button(action: { showOnlineSheet = true }) {
                            Label("Online Members (\(socketManager.onlineCount))", systemImage: "person.2")
                        }

                        if topic.isOwner || (socketManager.myProfile?.isModerator ?? false) {
                            if socketManager.currentTopic?.isLocked ?? topic.isLocked {
                                Button(action: { socketManager.unlockTopic() }) {
                                    Label("Unlock Topic", systemImage: "lock.open")
                                }
                            } else {
                                Button(action: { socketManager.lockTopic() }) {
                                    Label("Lock Topic", systemImage: "lock")
                                }
                            }

                            if !topic.isGeneral && !topic.isSystem {
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

                Divider().background(Color(hex: "#27272A"))

                // Messages Scroll List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            if socketManager.hasMoreHistory {
                                Button(action: {
                                    if let firstMsg = socketManager.chatMessages.first {
                                        socketManager.loadHistory(beforeId: firstMsg.msgId)
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
                                    onReply: { replyingToMessage = msg },
                                    onInspectUser: { socketManager.requestUserProfile(uid: msg.uid ?? msg.userId ?? "") }
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: socketManager.chatMessages.count) { _ in
                        if let last = socketManager.chatMessages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Reply Preview Bar
                if let rep = replyingToMessage {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Replying to \(rep.name)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#38BDF8"))
                            Text(rep.text.isEmpty ? "[Media]" : rep.text)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#A1A1AA"))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: { replyingToMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(hex: "#71717A"))
                        }
                    }
                    .padding(8)
                    .background(Color(hex: "#18181B"))
                }

                // Attached Images Strip
                if !attachedBase64Images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<attachedBase64Images.count, id: \.self) { idx in
                                ZStack(alignment: .topTrailing) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "#27272A"))
                                        .frame(width: 60, height: 60)

                                    Button(action: { attachedBase64Images.remove(at: idx) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .padding(4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .background(Color(hex: "#141416"))
                }

                // Bottom Input Bar
                HStack(spacing: 8) {
                    // Attachment button
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#38BDF8"))
                            .padding(8)
                    }
                    .onChange(of: selectedPhotos) { items in
                        Task {
                            for item in items {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let img = UIImage(data: data),
                                   let b64 = MediaUtils.compressImageToBase64(img) {
                                    attachedBase64Images.append(b64)
                                }
                            }
                            selectedPhotos.removeAll()
                        }
                    }

                    // Text Input
                    TextField("Message \(topic.name)...", text: $messageInput)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "#27272A"), lineWidth: 1)
                        )

                    // Send Button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? Color.blue : Color(hex: "#3F3F46"))
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(hex: "#121214"))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            socketManager.joinTopic(name: topic.name)
            if topic.name.lowercased() == "general" {
                socketManager.isGeneralActive = true
            }
        }
        .onDisappear {
            if topic.name.lowercased() == "general" {
                socketManager.isGeneralActive = false
            }
        }
        .sheet(isPresented: $showOnlineSheet) {
            OnlineMembersSheet()
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

    private var canSend: Bool {
        let hasText = !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !attachedBase64Images.isEmpty
        return hasText || hasMedia
    }

    private func sendMessage() {
        let clean = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let imgs = attachedBase64Images.isEmpty ? nil : attachedBase64Images
        let rName = replyingToMessage?.name
        let rText = replyingToMessage?.text
        let rId = replyingToMessage?.msgId

        socketManager.sendMessage(
            text: clean,
            images: imgs,
            replyName: rName,
            replyText: rText,
            replyMsgId: rId
        )

        messageInput = ""
        replyingToMessage = nil
        attachedBase64Images.removeAll()
    }
}
