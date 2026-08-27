import SwiftUI

public struct UserProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    public let profile: UserProfile
    @ObservedObject var prefs = PreferenceManager.shared

    public init(profile: UserProfile) {
        self.profile = profile
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar & Name
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(ColorHelper.avatarGradient(profile.displayColor))
                                    .frame(width: 80, height: 80)

                                if let av = profile.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                    CachedAsyncImage(url: avUrl) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.clear
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Text(String(profile.displayName.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#27272A"), lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)

                            VStack(spacing: 4) {
                                Text(profile.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)

                                if let uid = profile.uid, !uid.isEmpty {
                                    Text("UID: \(uid)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color(hex: "#71717A"))
                                }
                            }

                            if profile.isModerator {
                                Text("MODERATOR")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#EF4444"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.18))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.top, 16)

                        // Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(title: "Messages", value: "\(profile.messages ?? 0)")
                            StatCard(title: "Media Uploads", value: "\(profile.media ?? 0)")
                            StatCard(title: "Disk Used", value: profile.disk ?? "0 B")
                            StatCard(title: "Session ID", value: profile.userId != nil ? String(profile.userId!.prefix(8)) : "—")
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#38BDF8"))
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

public struct StatCard: View {
    public let title: String
    public let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: "#38BDF8"))
                .lineLimit(1)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#71717A"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color(hex: "#141416"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }
}
