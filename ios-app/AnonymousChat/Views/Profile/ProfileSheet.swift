import SwiftUI

public struct ProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var nameInput: String = ""
    @State private var showPhotoPicker: Bool = false
    @State private var selectedImages: [UIImage] = []
    @State private var avatarBase64: String?
    @State private var avatarImage: Image?
    @State private var showLogoutConfirm: Bool = false

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        avatarPickerSection
                        displayNameSection
                        soundToggleSection
                        timezoneSection
                        deviceMacSection
                        saveButton
                        logoutButton
                    }
                    .padding(.bottom, 24)
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
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(selectedImages: $selectedImages, maxSelectionCount: 1)
            }
            .onChange(of: selectedImages) { images in
                if let first = images.first {
                    avatarImage = Image(uiImage: first)
                    avatarBase64 = MediaUtils.compressImageToBase64(first, maxDimension: 512)
                }
                selectedImages.removeAll()
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

    // MARK: - Subviews

    private var avatarPickerSection: some View {
        VStack(spacing: 8) {
            Button(action: { showPhotoPicker = true }) {
                ZStack {
                    if let avImg = avatarImage {
                        avImg.resizable().scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                    } else if let myAv = socketManager.myProfile?.avatar,
                              let avUrl = MediaUtils.getFullMediaUrl(serverBaseUrl: prefs.serverBaseUrl, mediaPath: myAv) {
                        CachedAsyncImage(url: avUrl) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.clear }
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(ColorHelper.avatarGradient(socketManager.myProfile?.color))
                            .frame(width: 84, height: 84)
                        Text(String((socketManager.myProfile?.displayName ?? "A").prefix(1)).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack {
                        Spacer()
                        Text("Change")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.65))
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                }
            }

            Text("Tap avatar to change (JPEG, PNG, GIF, WebP)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#71717A"))
        }
        .padding(.top, 10)
    }

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Display Name")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#A1A1AA"))

            TextField("Display name...", text: $nameInput)
                .foregroundColor(.white)
                .padding(12)
                .background(Color(hex: "#18181B"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                )

            Text("Name can be changed once every 7 days")
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: "#71717A"))
        }
        .padding(.horizontal, 16)
    }

    private var soundToggleSection: some View {
        Toggle(isOn: $prefs.isSoundEnabled) {
            HStack(spacing: 10) {
                Image(systemName: prefs.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(prefs.isSoundEnabled ? Color(hex: "#38BDF8") : Color(hex: "#71717A"))
                Text("In-App Sound & Pop Audio")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .background(Color(hex: "#141416"))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message Timezone")
                .font(.system(size: 13, weight: .semibold))
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
    }

    private var deviceMacSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Device MAC Identifier")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#A1A1AA"))

            Text(prefs.deviceMac)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: "#38BDF8"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#18181B"))
                .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }

    private var saveButton: some View {
        Button(action: {
            let clean = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let newName = clean != socketManager.myProfile?.name ? clean : nil
            socketManager.updateProfile(name: newName, avatarBase64: avatarBase64)
            dismiss()
        }) {
            Text("Save Changes")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var logoutButton: some View {
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
}
