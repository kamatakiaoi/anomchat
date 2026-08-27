import SwiftUI

public struct InAppNotificationBannerView: View {
    public let banner: InAppNotification

    @ObservedObject var notifManager = NotificationManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @State private var dragOffset: CGFloat = 0

    public var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(ColorHelper.avatarGradient(banner.color))
                        .frame(width: 40, height: 40)

                    if let av = banner.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                        CachedAsyncImage(url: avUrl) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.clear }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Text(String(banner.title.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Text Container
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(banner.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#71717A"))

                        Text("now")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(hex: "#71717A"))
                    }

                    Text(banner.body)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#E4E4E7"))
                        .lineLimit(2)
                }

                Spacer()

                // Dismiss Button
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        notifManager.dismissBanner()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                        .padding(6)
                        .background(Circle().fill(Color(hex: "#27272A")))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color(hex: "#18181B")
                    .opacity(0.96)
            )
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "#333338"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.65), radius: 16, y: 8)
            .padding(.horizontal, 12)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height < -20 || value.velocity.height < -100 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                notifManager.dismissBanner()
                            }
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                notifManager.onBannerTapped()
            }

            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .zIndex(999)
    }
}
