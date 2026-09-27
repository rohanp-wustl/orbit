import Foundation

/// Mirrors the `profiles` table in Postgres — one row per Supabase Auth
/// user, `id` equal to `auth.uid()`. See docs/SUPABASE_SETUP.sql.
struct AppUser: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var createdAt: Date
    /// E.164 phone for iMessage delivery (docs/PHOTON.md). Optional so
    /// profiles from before STAGE5_MIGRATION still decode, and so upserts
    /// that don't set it leave it alone.
    var phone: String? = nil
    /// Lives in iMessage only (e.g. Grandma) — Ground Control delivers to them.
    var imessageOnly: Bool? = nil
    /// An app user who also wants landed capsules texted to them.
    var imessageUpdates: Bool? = nil

    init(id: UUID, displayName: String, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }

    var livesInIMessage: Bool { imessageOnly == true }
}
