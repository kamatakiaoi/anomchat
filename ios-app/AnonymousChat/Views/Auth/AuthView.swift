import SwiftUI

public struct AuthView: View {
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var keyInput: String = ""
    @State private var recoveryInput: String = ""
    @State private var isRecovering: Bool = false
    @State private var showServerConfig: Bool = false
    @State private var showCopySuccessToast: Bool = false

    public var body: some View {
        ZStack {
            Color(hex: "#0A0A0A").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Logo & App Name
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(
                                LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: Color.blue.opacity(0.4), radius: 10)

                        Text("Anonymous Chat")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Private, end-to-end encrypted messaging")
                            .font(.system(size: 13.5))
                            .foregroundColor(Color(hex: "#888888"))
                    }

                    // Card Container
                    VStack(spacing: 16) {
                        if let recoveryKey = socketManager.createdRecoveryKey {
                            // Key Created Success Panel
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Save your Recovery Key!", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#F59E0B"))

                                Text("If you lose your login key, this is the ONLY way to recover your account.")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Color(hex: "#CCCCCC"))

                                Button(action: {
                                    UIPasteboard.general.string = recoveryKey
                                    showCopySuccessToast = true
                                }) {
                                    HStack {
                                        Text(recoveryKey)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Color(hex: "#38BDF8"))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(Color(hex: "#38BDF8"))
                                    }
                                    .padding(12)
                                    .background(Color(hex: "#18181B"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "#38BDF8").opacity(0.4), lineWidth: 1)
                                    )
                                }

                                Button(action: {
                                    socketManager.createdRecoveryKey = nil
                                }) {
                                    Text("I Saved My Recovery Key -> Continue")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(16)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1)
                            )
                        } else if !isRecovering {
                            // Standard Login / Register Input
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Private Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#A1A1AA"))

                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(Color(hex: "#71717A"))
                                    SecureField("Enter or create a secret key...", text: $keyInput)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(12)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                            }

                            // Login & Create Buttons
                            HStack(spacing: 12) {
                                Button(action: {
                                    let clean = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !clean.isEmpty else { return }
                                    socketManager.authKey(key: clean)
                                }) {
                                    Text("Log In")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }

                                Button(action: {
                                    let clean = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !clean.isEmpty else { return }
                                    socketManager.createKey(key: clean)
                                }) {
                                    Text("Create Key")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#38BDF8"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#18181B"))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(hex: "#38BDF8").opacity(0.4), lineWidth: 1)
                                        )
                                }
                            }

                            // Toggle Forgot Key
                            Button(action: { isRecovering = true }) {
                                Text("Forgot your key? Recover it")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#94A3B8"))
                            }
                            .padding(.top, 4)

                        } else {
                            // Recover Account with Recovery Key
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Recovery Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#A1A1AA"))

                                HStack {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                        .foregroundColor(Color(hex: "#71717A"))
                                    TextField("Paste your recovery key...", text: $recoveryInput)
                                        .foregroundColor(.white)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding(12)
                                .background(Color(hex: "#18181B"))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "#27272A"), lineWidth: 1)
                                )
                            }

                            Button(action: {
                                let clean = recoveryInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !clean.isEmpty else { return }
                                socketManager.recoverKey(recoveryKey: clean)
                            }) {
                                Text("Recover Account")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }

                            Button(action: { isRecovering = false }) {
                                Text("Back to Login")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#94A3B8"))
                            }
                            .padding(.top, 4)
                        }

                        // Auth Error display
                        if let authErr = socketManager.authErrorMessage {
                            Text(authErr)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .background(Color(hex: "#121214"))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#27272A"), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Server Configuration button
                    Button(action: { showServerConfig = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 12))
                            Text("Server: \(prefs.serverHost):\(prefs.serverPort)")
                                .font(.system(size: 12.5))
                        }
                        .foregroundColor(Color(hex: "#71717A"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigSheet()
        }
        .alert("Copied to Clipboard", isPresented: $showCopySuccessToast) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Recovery key copied. Please store it in a safe place.")
        }
    }
}

public struct ServerConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var prefs = PreferenceManager.shared
    @State private var hostInput: String = ""
    @State private var portInput: String = ""

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Host")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        TextField("snow.pikamc.vn", text: $hostInput)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Port")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        TextField("25222", text: $portInput)
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                    }

                    Button(action: {
                        prefs.serverHost = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let p = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            prefs.serverPort = p
                        }
                        SocketManager.shared.connect()
                        dismiss()
                    }) {
                        Text("Save & Reconnect")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                hostInput = prefs.serverHost
                portInput = "\(prefs.serverPort)"
            }
        }
    }
}
