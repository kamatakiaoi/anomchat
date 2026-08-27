import SwiftUI

public struct OnlineMembersSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var selectedMember: UserProfile?

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if socketManager.onlineMembers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#52525B"))
                        Text("No other members currently online in this topic")
                            .font(.system(size: 13.5))
                            .foregroundColor(Color(hex: "#71717A"))
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(socketManager.onlineMembers) { member in
                                Button(action: {
                                    selectedMember = member
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(ColorHelper.avatarGradient(member.displayColor))
                                                .frame(width: 38, height: 38)

                                            if let av = member.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: av) {
                                                CachedAsyncImage(url: avUrl) { img in
                                                    img.resizable().scaledToFill()
                                                } placeholder: {
                                                    Color.clear
                                                }
                                                .frame(width: 38, height: 38)
                                                .clipShape(Circle())
                                            } else {
                                                Text(String(member.displayName.prefix(1)).uppercased())
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(member.displayName)
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

                                        Circle().fill(Color(hex: "#22C55E")).frame(width: 8, height: 8)
                                    }
                                    .padding(10)
                                    .background(Color(hex: "#141416"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Online Members (\(max(socketManager.onlineCount, socketManager.onlineMembers.count)))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .sheet(item: $selectedMember) { member in
                UserProfileSheet(profile: member)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
