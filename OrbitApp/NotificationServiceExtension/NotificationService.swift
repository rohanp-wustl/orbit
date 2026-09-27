// DEFERRED for the free-tier MVP: real push notifications need the Push
// Notifications entitlement, which a free "Personal Team" can't sign (see
// docs/PUSH_AND_WIDGET_PLAN.md). Don't add this as a target in Xcode yet —
// Supabase Realtime listeners are the delivery mechanism for now. Come back
// to this file once there's a paid account.

import UserNotifications

/// Runs when a landed-capsule push arrives, before it's shown to the user.
/// Downloads the small preview image the Cloud Function generated and
/// attaches it, so the recipient sees a glimpse of the capsule right on the
/// lock screen notification — not just text.
///
/// Requires the push payload to include a custom key with the preview image
/// URL, e.g.:
///   "aps": { "mutable-content": 1, "alert": { "title": "...", "body": "..." } },
///   "previewImageURL": "https://.../capsules/{id}/preview.jpg"
/// (a signed/public download URL from Cloud Storage — generate it in the
/// same place that sends the push; see docs/PUSH_AND_WIDGET_PLAN.md.)
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        bestAttemptContent = content

        guard let urlString = request.content.userInfo["previewImageURL"] as? String,
              let url = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, _, _ in
            guard let self, let location else {
                contentHandler(content)
                return
            }
            // Notification attachments must be moved to a location the
            // system can hand off between processes — a plain file:// URL
            // from the download task's temp location won't survive.
            let tmpDir = FileManager.default.temporaryDirectory
            let destination = tmpDir.appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try FileManager.default.moveItem(at: location, to: destination)
                let attachment = try UNNotificationAttachment(identifier: "preview", url: destination)
                content.attachments = [attachment]
            } catch {
                // Non-fatal: fall back to a text-only notification rather
                // than dropping the notification entirely.
            }
            self.contentHandler?(content)
        }
        task.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        // Apple gives this extension a short, strict time budget. If we hit
        // it, show whatever we've got rather than nothing.
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
