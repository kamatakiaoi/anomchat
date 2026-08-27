import SwiftUI

public struct CommentRowView: View {
    public let comment: Comment
    public let onReply: () -> Void

    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    public var isReply: Bool {
        return (comment.parentId ?? 0) > 0
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar with Profile Inspect
            Button(action: {
                if let uid = comment.uid, !uid.isEmpty {
                    socketManager.requestUserProfile(uid: uid)
                } else if let uid = comment.userId, !uid.isEmpty {
                    socketManager.requestUserProfile(uid: uid)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(ColorHelper.avatarGradient(comment.authorColor))
                        .frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)

                    if let av = comment.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                        CachedAsyncImage(url: avUrl) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: isReply ? 28 : 32, height: isReply ? 28 : 32)
                        .clipShape(Circle())
                    } else {
                        Text(String(comment.authorName.prefix(1)).uppercased())
                            .font(.system(size: isReply ? 11 : 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle().stroke(Color(hex: "#27272A"), lineWidth: 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Body content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    if let rName = comment.replyName, !rName.isEmpty {
                        Text("▸ \(rName)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(TimeUtils.formatRelativeTime(comment.commentTime))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#71717A"))
                }

                if !comment.commentBody.isEmpty {
                    FormattedMarkdownText(
                        text: comment.commentBody,
                        fontSize: 13.5,
                        fontColor: Color(hex: "#E4E4E7")
                    )
                }

                // Reply Button
                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10))
                        Text("Reply")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#38BDF8"))
                    .padding(.top, 2)
                }
            }
        }
        .padding(.leading, isReply ? 24 : 0)
        .padding(10)
        .background(isReply ? Color(hex: "#101012") : Color(hex: "#141416"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isReply ? Color(hex: "#1F1F23") : Color(hex: "#27272A"), lineWidth: 1)
        )
    }
}
