import SwiftUI
import PhotosUI

public struct ProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var nameInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarBase64: String?
    @State private var avatarImage: Image?
    @State private var showLogoutConfirm: Bool = false

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Photo Picker
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack {
                                    if let avImg = avatarImage {
                                        avImg.resizable().scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else if let myAv = socketManager.myProfile?.avatar, let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: myAv) {
                                        AsyncImage(url: avUrl) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: { Color.clear }
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(ColorHelper.avatarGradient(socketManager.myProfile?.color))
                                            .frame(width: 80, height: 80)
                                        Text(String(socketManager.myProfile?.name.prefix(1) ?? "A").uppercased())
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                    }

                                    VStack {
                                        Spacer()
                                        Text("Change")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.6))
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                }
                            }
                            .onChange(of: selectedPhotoItem) { item in
                                Task {
                                    if let data = try? await item?.loadTransferable(type: Data.self),
                                       let uiImg = UIImage(data: data),
                                       let b64 = MediaUtils.compressImageToBase64(uiImg, maxDimension: 512) {
                                        avatarBase64 = b64
                                        avatarImage = Image(uiImage: uiImg)
                                    }
                                }
                            }

                            Text("Tap avatar to upload new photo")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#71717A"))
                        }
                        .padding(.top, 10)

                        // Name Input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Display Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#A1A1AA"))

                            TextField("Display name...", text: $nameInput)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(10)

                            Text("Name can be changed once every 7 days")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#71717A"))
                        }
                        .padding(.horizontal, 16)

                        // Timezone Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message Timezone")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#A1A1AA"))

                            HStack(spacing: 12) {
                                Button(action: { prefs.timezone = "vn" }) {
                                    HStack {
                                        Text("Vietnam (GMT+7)")
                                            .font(.system(size: 13.5, weight: .medium))
                                        Spacer()
                                        if prefs.timezone == "vn" {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "#18181B"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(prefs.timezone == "vn" ? Color.blue : Color(hex: "#27272A"), lineWidth: 1)
                                    )
                                }

                                Button(action: { prefs.timezone = "utc" }) {
                                    HStack {
                                        Text("UTC")
                                            .font(.system(size: 13.5, weight: .medium))
                                        Spacer()
                                        if prefs.timezone == "utc" {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "#18181B"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(prefs.timezone == "utc" ? Color.blue : Color(hex: "#27272A"), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Save Button
                        Button(action: {
                            let clean = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            let newName = clean != socketManager.myProfile?.name ? clean : nil
                            socketManager.updateProfile(name: newName, avatarBase64: avatarBase64)
                            dismiss()
                        }) {
                            Text("Save Profile")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        // Logout Button
                        Button(action: { showLogoutConfirm = true }) {
                            Text("Log Out")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                nameInput = socketManager.myProfile?.name ?? ""
            }
            .alert("Log Out", isPresented: $showLogoutConfirm) {
                Button("Log Out", role: .destructive) {
                    socketManager.logout()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}

public struct PatchNotesView: View {
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Version 3.6.6")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("LATEST")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#38BDF8"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(6)
                            }

                            Text("Official Native iOS Client release for Apple devices with 120Hz ProMotion UI, instant notifications, multi-mac persistent device authorization, explore feed, and high performance chat.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#A1A1AA"))
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .background(Color(hex: "#141416"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#27272A"), lineWidth: 1)
                        )
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Patch Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
