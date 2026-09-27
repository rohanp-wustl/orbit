import Foundation
import UIKit
import UserNotifications

/// Rich "capsule landed" notifications without a paid Apple Developer
/// account. Remote push (APNs) needs the paid membership, but LOCAL
/// notifications don't: when the recipient's app learns about an inbound
/// rocket (Realtime or reload), it schedules its own notification for the
/// landing time, with the capsule's first photo attached — so it still
/// fires on the lock screen if the app has been closed since.
/// Toggle: Settings → Notifications → Landing alerts.
enum LandingNotifications {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "landingAlerts") as? Bool ?? true }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Recipient side: "Maya's capsule landed!" at deliveryAt. Idempotent —
    /// uses the capsule id, so rescheduling just replaces it.
    static func scheduleArrival(of capsule: Capsule, from senderName: String) async {
        guard enabled, let deliveryAt = capsule.deliveryAt, deliveryAt > .now.addingTimeInterval(2) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(senderName)'s capsule landed!"
        content.body = "A package is waiting on your launchpad. Tap to open it."
        content.sound = .default
        content.userInfo = ["capsuleId": capsule.id.uuidString]
        if let attachment = await previewAttachment(for: capsule) {
            content.attachments = [attachment]
        }
        await add(id: "arrive-\(capsule.id)", content: content, at: deliveryAt)
    }

    /// Sender side, for longer flights: "Your capsule landed at Maya's planet."
    static func scheduleDelivered(_ capsule: Capsule, to recipientName: String) async {
        guard enabled, let deliveryAt = capsule.deliveryAt, deliveryAt > .now.addingTimeInterval(60) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Delivered to \(recipientName)"
        content.body = "Your capsule touched down on their planet."
        content.sound = .default
        await add(id: "delivered-\(capsule.id)", content: content, at: deliveryAt)
    }

    static func cancel(for capsule: Capsule) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["arrive-\(capsule.id)"])
    }

    private static func add(id: String, content: UNNotificationContent, at date: Date) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// The capsule's first photo as a notification thumbnail (the "rich" part).
    private static func previewAttachment(for capsule: Capsule) async -> UNNotificationAttachment? {
        guard let mediaId = capsule.layout.items.first(where: { $0.type == .photo })?.media,
              let image = await MediaRepository.shared.image(mediaId: mediaId, senderId: capsule.senderId),
              let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notif-\(capsule.id).jpg")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "preview", url: url)
    }
}
