import SwiftUI
import UniformTypeIdentifiers

public struct CreatePostSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var tagsText: String = ""
    @State private var showPhotoPicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var base64Images: [String] = []
    @State private var attachedVideoBase64: String?
    @State private var attachedVideoName: String?
    @State private var attachedAudioBase64: String?
    @State private var attachedAudioName: String?
    @State private var isSubmitting: Bool = false
    @State private var localError: String?

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Title")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#A1A1AA"))

                            TextField("Post title (min 2 chars)...", text: $title)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                        }

                        // Body Field & Formatting Toolbar (Bold / Strike)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Content")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#A1A1AA"))

                                Spacer()

                                // Formatting Buttons
                                HStack(spacing: 8) {
                                    Button(action: insertBold) {
                                        Text("B")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 28, height: 24)
                                            .background(Color(hex: "#27272A"))
                                            .cornerRadius(6)
                                    }

                                    Button(action: insertStrike) {
                                        Text("S")
                                            .font(.system(size: 13, weight: .semibold))
                                            .strikethrough()
                                            .foregroundColor(.white)
                                            .frame(width: 28, height: 24)
                                            .background(Color(hex: "#27272A"))
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            ZStack(alignment: .topLeading) {
                                if bodyText.isEmpty {
                                    Text("What's on your mind? (Markdown supported: **bold**, ~~strike~~)")
                                        .foregroundColor(Color(hex: "#52525B"))
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                }

                                TextEditor(text: $bodyText)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                                    .frame(minHeight: 110)
                                    .padding(8)
                                    .background(Color.clear)
                            }
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#27272A"), lineWidth: 1)
                            )
                        }

                        // Tags Field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags (comma separated)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: "#A1A1AA"))

                            TextField("talk, school, tech", text: $tagsText)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                        }

                        // Media Attachments Section (Photos / Video / Audio)
                        mediaAttachmentSection

                        // Error Banner
                        if let err = localError ?? socketManager.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "#EF4444"))
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#EF4444"))
                            }
                            .padding(.top, 4)
                        }

                        // Publish Post Button
                        Button(action: submitPost) {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                        .scaleEffect(0.85)
                                }
                                Text(isSubmitting ? "Publishing..." : "Publish Post")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? Color.blue : Color(hex: "#27272A"))
                            .cornerRadius(10)
                        }
                        .disabled(!canSubmit || isSubmitting)
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Explore Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(selectedImages: $selectedImages, maxSelectionCount: 5 - base64Images.count)
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(allowedContentTypes: [.movie, .audio, .data]) { url in
                    handleDocumentPicked(url: url)
                }
            }
            .onChange(of: selectedImages) { images in
                for img in images {
                    if base64Images.count < 5, let b64 = MediaUtils.compressImageToBase64(img) {
                        base64Images.append(b64)
                    }
                }
                selectedImages.removeAll()
            }
            .onChange(of: socketManager.postCreatedSuccessfully) { success in
                if success {
                    isSubmitting = false
                    dismiss()
                }
            }
            .onChange(of: socketManager.errorMessage) { err in
                if err != nil {
                    isSubmitting = false
                }
            }
        }
    }

    // MARK: - Subviews

    private var mediaAttachmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attach Media")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#A1A1AA"))

            HStack(spacing: 12) {
                // Add Photos Button
                Button(action: {
                    if attachedVideoBase64 == nil && attachedAudioBase64 == nil {
                        showPhotoPicker = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                        Text("Photos (\(base64Images.count)/5)")
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(attachedVideoBase64 != nil || attachedAudioBase64 != nil ? Color(hex: "#52525B") : Color(hex: "#38BDF8"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#18181B"))
                    .cornerRadius(8)
                }
                .disabled(attachedVideoBase64 != nil || attachedAudioBase64 != nil || base64Images.count >= 5)

                // Add Video or Audio Button
                Button(action: {
                    if base64Images.isEmpty {
                        showDocumentPicker = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "film.stack")
                        Text(attachedVideoBase64 != nil ? "Video Attached" : attachedAudioBase64 != nil ? "Audio Attached" : "Video/Audio")
                    }
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(!base64Images.isEmpty ? Color(hex: "#52525B") : Color(hex: "#F59E0B"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#18181B"))
                    .cornerRadius(8)
                }
                .disabled(!base64Images.isEmpty)
            }

            // Photos Preview Strip
            if !base64Images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(base64Images.enumerated()), id: \.offset) { index, b64 in
                            let cleanB64 = b64.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                            if let data = Data(base64Encoded: cleanB64), let uiImg = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button(action: {
                                        base64Images.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.black))
                                    }
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Video Preview Badge
            if let vName = attachedVideoName {
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(Color(hex: "#38BDF8"))
                    Text(vName)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        attachedVideoBase64 = nil
                        attachedVideoName = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(10)
                .background(Color(hex: "#18181B"))
                .cornerRadius(8)
            }

            // Audio Preview Badge
            if let aName = attachedAudioName {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(Color(hex: "#F59E0B"))
                    Text(aName)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        attachedAudioBase64 = nil
                        attachedAudioName = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(10)
                .background(Color(hex: "#18181B"))
                .cornerRadius(8)
            }
        }
    }

    private var canSubmit: Bool {
        return title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func insertBold() {
        bodyText += "**bold text**"
    }

    private func insertStrike() {
        bodyText += "~~strikethrough~~"
    }

    private func handleDocumentPicked(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov", "webm"].contains(ext) {
            if let b64 = MediaUtils.fileDataToBase64(url: url) {
                attachedVideoBase64 = b64
                attachedVideoName = url.lastPathComponent
                attachedAudioBase64 = nil
                attachedAudioName = nil
                base64Images.removeAll()
                localError = nil
            } else {
                localError = "Failed to load video file (max 50MB)"
            }
        } else if ["mp3", "wav", "m4a", "ogg", "aac"].contains(ext) {
            if let b64 = MediaUtils.fileDataToBase64(url: url) {
                attachedAudioBase64 = b64
                attachedAudioName = url.lastPathComponent
                attachedVideoBase64 = nil
                attachedVideoName = nil
                base64Images.removeAll()
                localError = nil
            } else {
                localError = "Failed to load audio file (max 50MB)"
            }
        }
    }

    private func submitPost() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTitle.count >= 2 else { return }

        isSubmitting = true
        localError = nil
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        socketManager.createExplorePost(
            title: cleanTitle,
            body: cleanBody,
            tags: rawTags,
            images: base64Images.isEmpty ? nil : base64Images,
            video: attachedVideoBase64,
            audio: attachedAudioBase64
        )

        // Fallback watchdog timer (10s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isSubmitting {
                self.isSubmitting = false
                self.localError = "Posting timeout. Please check your network connection."
            }
        }
    }
}
