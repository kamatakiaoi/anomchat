import SwiftUI

public struct ServerConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var prefs = PreferenceManager.shared
    @ObservedObject var socketManager = SocketManager.shared

    @State private var hostInput: String = ""
    @State private var portInput: String = ""

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 20) {
                    // Status Badge
                    HStack(spacing: 10) {
                        Circle()
                            .fill(socketManager.isConnected ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                            .frame(width: 10, height: 10)

                        Text(socketManager.isConnected ? "Connected to Server" : "Disconnected")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(socketManager.pingMs) ms")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#38BDF8"))
                    }
                    .padding(14)
                    .background(Color(hex: "#141416"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#27272A"), lineWidth: 1)
                    )

                    // Host Input Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server Host / Domain")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        TextField("e.g. snow.pikamc.vn", text: $hostInput)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#27272A"), lineWidth: 1)
                            )
                    }

                    // Port Input Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server Port")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        TextField("25222", text: $portInput)
                            .foregroundColor(.white)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#27272A"), lineWidth: 1)
                            )
                    }

                    // Connect Button
                    Button(action: applyAndConnect) {
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
                .padding(16)
            }
            .navigationTitle("Server Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                hostInput = prefs.serverHost
                portInput = "\(prefs.serverPort)"
            }
        }
    }

    private func applyAndConnect() {
        let cleanHost = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHost.isEmpty {
            prefs.serverHost = cleanHost
        }
        if let p = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)), p > 0 {
            prefs.serverPort = p
        }
        socketManager.connect()
        dismiss()
    }
}
