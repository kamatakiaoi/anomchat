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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 30)

                    // Logo & App Name
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(
                                LinearGradient(colors: [Color.blue, Color(hex: "#38BDF8")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: Color.blue.opacity(0.35), radius: 12)

                        Text("Anonymous Chat")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Private, end-to-end encrypted messaging")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#888888"))
                    }

                    // Card Container (Adaptive width max 440 for iPad/Pro Max, full width on small screens)
                    VStack(spacing: 16) {
                        if let recoveryKey = socketManager.createdRecoveryKey {
                            recoverySuccessCard(recoveryKey: recoveryKey)
                        } else if !isRecovering {
                            loginCard
                        } else {
                            recoveryCard
                        }

                        // Auth Error display
                        if let authErr = socketManager.authErrorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(authErr)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#EF4444"))
                            .padding(.top, 4)
                            .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 440)
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
                            Circle()
                                .fill(socketManager.isConnected ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                                .frame(width: 7, height: 7)

                            Image(systemName: "server.rack")
                                .font(.system(size: 12))
                            Text("Server: \(prefs.serverHost):\(prefs.serverPort)")
                                .font(.system(size: 12.5))
                        }
                        .foregroundColor(Color(hex: "#A1A1AA"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#18181B"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "#27272A"), lineWidth: 1)
                        )
                    }

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            if let saved = prefs.authKey, !saved.isEmpty {
                keyInput = saved
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

    // MARK: - Subcards

    private var loginCard: some View {
        VStack(spacing: 16) {
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
                Button(action: handleLogin) {
                    HStack {
                        if socketManager.isAuthenticating {
                            ProgressView().tint(.white)
                                .scaleEffect(0.85)
                        }
                        Text(socketManager.isAuthenticating ? "Logging in..." : "Log In")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || socketManager.isAuthenticating)

                Button(action: handleCreateKey) {
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
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || socketManager.isAuthenticating)
            }

            // Toggle Forgot Key
            Button(action: { isRecovering = true }) {
                Text("Forgot your key? Recover it")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(.top, 4)
        }
    }

    private var recoveryCard: some View {
        VStack(spacing: 16) {
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

            Button(action: handleRecover) {
                HStack {
                    if socketManager.isAuthenticating {
                        ProgressView().tint(.white)
                            .scaleEffect(0.85)
                    }
                    Text(socketManager.isAuthenticating ? "Recovering..." : "Recover Account")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(recoveryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || socketManager.isAuthenticating)

            Button(action: { isRecovering = false }) {
                Text("Back to Login")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(.top, 4)
        }
    }

    private func recoverySuccessCard(recoveryKey: String) -> some View {
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
    }

    // MARK: - Actions
    private func handleLogin() {
        let clean = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        socketManager.authKey(key: clean)
    }

    private func handleCreateKey() {
        let clean = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        socketManager.createKey(key: clean)
    }

    private func handleRecover() {
        let clean = recoveryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        socketManager.recoverKey(recoveryKey: clean)
    }
}
