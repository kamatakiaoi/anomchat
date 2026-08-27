import SwiftUI

@main
struct AnonymousChatApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var socketManager = SocketManager.shared
    @StateObject private var prefs = PreferenceManager.shared
    @StateObject private var notifManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    socketManager.connect()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                socketManager.appDidEnterBackground()
            case .active:
                socketManager.appWillEnterForeground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

public struct ContentView: View {
    @ObservedObject var socketManager = SocketManager.shared
    @ObservedObject var prefs = PreferenceManager.shared
    @ObservedObject var notifManager = NotificationManager.shared

    public var body: some View {
        ZStack {
            Group {
                if socketManager.myProfile != nil {
                    MainLobbyView()
                } else {
                    AuthView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: socketManager.myProfile != nil)

            if let banner = notifManager.activeBanner {
                InAppNotificationBannerView(banner: banner)
            }
        }
    }
}

// SwiftUI Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
