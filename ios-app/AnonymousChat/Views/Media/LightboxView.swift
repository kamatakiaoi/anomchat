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

    public init(mediaUrl: URL, isVideo: Bool = false) {
        self.mediaUrl = mediaUrl
        let path = mediaUrl.absoluteString.lowercased()
        self.isVideo = isVideo || path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".webm")
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isVideo {
                VideoPlayerView(videoUrl: mediaUrl)
            } else {
                AsyncImage(url: mediaUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = max(1.0, lastScale * value)
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            if scale <= 1.0 {
                                                withAnimation {
                                                    scale = 1.0
                                                    lastScale = 1.0
                                                    offset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                            )
                    case .failure(_):
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .foregroundColor(.gray)
                        }
                    default:
                        ProgressView().tint(.white)
                    }
                }

                // Top Close Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(16)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}
