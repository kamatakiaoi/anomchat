import SwiftUI
import UserNotifications
import AudioToolbox

public struct InAppNotification: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let body: String
    public let avatar: String?
    public let color: String
    public let topicName: String
}

public class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    @Published public var activeBanner: InAppNotification?

    private var bannerTimer: Timer?

    private init() {
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    public func showGeneralNotification(sender: String, message: Message, isAppActive: Bool, isGeneralActive: Bool) {
        if isGeneralActive { return }

        var displayBody = message.text
        if displayBody.isEmpty {
            if let imgs = message.images, !imgs.isEmpty { displayBody = "[Photo]" }
            else if message.video != nil { displayBody = "[Video]" }
            else if message.audio != nil { displayBody = "[Audio Clip]" }
            else { displayBody = "[Message]" }
        }

        // 1. Play standard iOS haptic & sound feedback
        AudioServicesPlaySystemSound(1007) // iOS SMS/Chat Tri-tone
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // 2. If app is open in foreground (but not viewing General), show Messenger-style in-app drop-down banner
        if isAppActive {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    self.activeBanner = InAppNotification(
                        title: "\(sender) in General",
                        body: displayBody,
                        avatar: message.avatar,
                        color: message.color,
                        topicName: "General"
                    )
                }

                self.bannerTimer?.invalidate()
                self.bannerTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        self?.activeBanner = nil
                    }
                }
            }
        } else {
            // 3. If app is in background, show iOS system lockscreen / dynamic island banner
            let content = UNMutableNotificationContent()
            content.title = "\(sender) in General"
            content.body = displayBody
            content.sound = UNNotificationSound.default
            content.categoryIdentifier = "GENERAL_CHAT"

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    public func dismissBanner() {
        withAnimation(.easeOut(duration: 0.2)) {
            activeBanner = nil
        }
    }
}
