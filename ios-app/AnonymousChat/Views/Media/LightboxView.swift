import SwiftUI
import AVKit

public struct LightboxView: View {
    @Environment(\.dismiss) var dismiss
    public let mediaUrl: URL
    public var isVideo: Bool = false

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragDismissOffset: CGFloat = 0

    public init(mediaUrl: URL, isVideo: Bool = false) {
        self.mediaUrl = mediaUrl
        let path = mediaUrl.absoluteString.lowercased()
        let isVidExt = path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".webm") ||
            path.hasSuffix(".mkv") || path.hasSuffix(".m4v") || path.hasSuffix(".ts") ||
            path.hasSuffix(".3gp") || path.hasSuffix(".avi") || path.hasSuffix(".flv") ||
            path.hasPrefix("data:video/") || path.contains("/video/")
        self.isVideo = isVideo || isVidExt
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .opacity(Double(1.0 - min(0.7, max(0.0, abs(dragDismissOffset) / 300.0))))
                .onTapGesture {
                    dismiss()
                }

            if isVideo {
                VideoPlayerView(videoUrl: mediaUrl)
            } else {
                CachedAsyncImage(url: mediaUrl) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dragDismissOffset)
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        if scale > 1.2 {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        } else {
                                            scale = 2.5
                                            lastScale = 2.5
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 1)
                                .onEnded {
                                    if scale <= 1.05 {
                                        dismiss()
                                    }
                                }
                        )
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1.0, min(5.0, lastScale * value))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.05 {
                                            withAnimation(.spring(response: 0.25)) {
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.05 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        } else {
                                            if value.translation.height > 0 {
                                                dragDismissOffset = value.translation.height
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        if scale > 1.05 {
                                            lastOffset = offset
                                        } else {
                                            if value.translation.height > 90 {
                                                dismiss()
                                            } else {
                                                withAnimation(.spring(response: 0.25)) {
                                                    dragDismissOffset = 0
                                                }
                                            }
                                        }
                                    }
                            )
                        )
                } placeholder: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }

            // Top Close Button (for image view only, VideoPlayerView has its own controls)
            if !isVideo {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }
        }
    }
}
