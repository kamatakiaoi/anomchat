import SwiftUI

public struct OnlineMembersSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(socketManager.onlineMembers) { member in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(ColorHelper.avatarGradient(member.color))
                                        .frame(width: 38, height: 38)

                                    if let av = member.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                        AsyncImage(url: avUrl) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: { Color.clear }
                                        .frame(width: 38, height: 38)
                                        .clipShape(Circle())
                                    } else {
                                        Text(String(member.name.prefix(1)).uppercased())
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(member.name)
                                            .font(.system(size: 14.5, weight: .semibold))
                                            .foregroundColor(.white)

                                        if member.isModerator {
                                            Text("MOD")
                                                .font(.system(size: 9.5, weight: .bold))
                                                .foregroundColor(Color(hex: "#EF4444"))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.red.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                    }
                                }

                                Spacer()

                                Circle().fill(Color.green).frame(width: 8, height: 8)
                            }
                            .padding(10)
                            .background(Color(hex: "#141416"))
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Online Members (\(socketManager.onlineMembers.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

public struct UserProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    public let profile: UserProfile
    @ObservedObject var prefs = PreferenceManager.shared

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 20) {
                    // Avatar & Name
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(ColorHelper.avatarGradient(profile.color))
                                .frame(width: 72, height: 72)

                            if let av = profile.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                AsyncImage(url: avUrl) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: { Color.clear }
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                            } else {
                                Text(String(profile.name.prefix(1)).uppercased())
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Text(profile.name)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)

                        if profile.isModerator {
                            Text("MODERATOR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.top, 20)

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Messages", value: "\(profile.messages ?? 0)")
                        StatCard(title: "Media Uploads", value: "\(profile.media ?? 0)")
                        StatCard(title: "Disk Used", value: profile.disk ?? "0 B")
                        StatCard(title: "User ID", value: profile.id)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

public struct StatCard: View {
    public let title: String
    public let value: String

    public var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#38BDF8"))
                .lineLimit(1)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#71717A"))
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color(hex: "#141416"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }
}
