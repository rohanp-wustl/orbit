import Foundation

enum CapsuleStatus: String, Codable {
    case draft
    case launched
    case inTransit = "in_transit"
    case landed
    case opened
}

/// Mirrors the `capsules` table in Postgres (Supabase) — see
/// docs/SUPABASE_SETUP.sql for the schema and RLS policies. `id` defaults
/// to `gen_random_uuid()` in Postgres, so it can be omitted on insert and
/// left for the database to assign.
struct Capsule: Codable, Identifiable, Equatable {
    var id: UUID
    var senderId: UUID
    var recipientId: UUID
    var crewLinkId: UUID
    var status: CapsuleStatus
    var layout: CapsuleLayout
    var createdAt: Date
    var launchedAt: Date?
    var deliveryAt: Date?
    /// Demo-day override so a multi-phone demo can use seconds instead of
    /// the "real" delay. See README assumption 5.
    var deliveryDelaySeconds: Int
    var openedAt: Date?
    /// Storage path for the page snapshot (texted to iMessage recipients).
    var previewImagePath: String?
    /// "imessage" when the capsule was sent by replying to Ground Control in
    /// iMessage (docs/PHOTON.md). Optional: older rows and app sends omit it.
    var source: String? = nil

    var cameFromIMessage: Bool { source == "imessage" }

    init(id: UUID = UUID(), senderId: UUID, recipientId: UUID, crewLinkId: UUID,
         status: CapsuleStatus = .draft, layout: CapsuleLayout,
         createdAt: Date = Date(), launchedAt: Date? = nil, deliveryAt: Date? = nil,
         deliveryDelaySeconds: Int = 10, openedAt: Date? = nil,
         previewImagePath: String? = nil) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.crewLinkId = crewLinkId
        self.status = status
        self.layout = layout
        self.createdAt = createdAt
        self.launchedAt = launchedAt
        self.deliveryAt = deliveryAt
        self.deliveryDelaySeconds = deliveryDelaySeconds
        self.openedAt = openedAt
        self.previewImagePath = previewImagePath
    }
}
