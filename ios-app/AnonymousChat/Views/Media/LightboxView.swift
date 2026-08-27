import SwiftUI

public struct LightboxView: View {
    @Environment(\.dismiss) var dismiss
    public let mediaUrl: URL

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: mediaUrl) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation { scale = 1.0; lastScale = 1.0 }
                                }
                            }
                    )
            } placeholder: {
                ProgressView().tint(.white)
            }

            // Top Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
    }
}
