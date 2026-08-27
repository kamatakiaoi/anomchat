import SwiftUI
import UserNotifications
import AudioToolbox
import UIKit

public struct InAppNotification: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let body: String
    public let avatar: String?
    public let color: String
    public let topicName: String
}

public class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    @Published public var activeBanner: InAppNotification?
    @Published public var shouldNavigateToGeneral: Bool = false

    private var bannerTimer: Timer?
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        impactFeedback.prepare()
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            self.shouldNavigateToGeneral = true
        }
        completionHandler()
    }

    // MARK: - Lightning-Fast General Chat Notification Dispatcher
    public func showGeneralNotification(sender: String, message: Message, isAppActive: Bool = true, isGeneralActive: Bool = false) {
        // Do not notify if user is currently inside and actively viewing General topic
        if isGeneralActive { return }

        var displayBody = message.bodyText
        if displayBody.isEmpty {
            if !message.allImages.isEmpty { displayBody = "📷 [Photo]" }
            else if message.video != nil { displayBody = "📹 [Video]" }
            else if message.audio != nil { displayBody = "🎙️ [Voice Note]" }
            else { displayBody = "[Message]" }
        }

        // 1. Instant Sound & Haptics (0ms latency)
        if PreferenceManager.shared.isSoundEnabled {
            SoundHelper.shared.playPop()
            impactFeedback.impactOccurred()
            impactFeedback.prepare()
        }

        // 2. In-App Heads-up Notification (Ultra-fast Spring Animation)
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                self.activeBanner = InAppNotification(
                    title: "\(sender) in General",
                    body: displayBody,
                    avatar: message.avatar,
                    color: message.authorColor,
                    topicName: "General"
                )
            }

            self.bannerTimer?.invalidate()
            self.bannerTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    self?.activeBanner = nil
                }
            }
        }

        // 3. System Lockscreen / Notification Center Delivery
        let content = UNMutableNotificationContent()
        content.title = "\(sender) in General"
        content.body = displayBody
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "GENERAL_CHAT"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    public func dismissBanner() {
        bannerTimer?.invalidate()
        bannerTimer = nil
        activeBanner = nil
    }

    public func onBannerTapped() {
        dismissBanner()
        shouldNavigateToGeneral = true
    }
}
