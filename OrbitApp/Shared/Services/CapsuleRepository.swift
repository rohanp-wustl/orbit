import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// Reads/writes Capsule rows in Postgres via Supabase, and exposes a
/// Realtime subscription so a recipient's UI updates the moment a status
/// changes — this replaces the old push-notification + Firestore-listener
/// combo. See docs/PUSH_AND_WIDGET_PLAN.md for why: a free Apple ID can't
/// sign the Push Notifications entitlement, so for the free-tier MVP,
/// "the app is open and subscribed" IS the delivery mechanism, not a
/// fallback for one.
///
/// VERSION NOTE: written against supabase-swift's current Postgrest +
/// Realtime v2 API shape. Confirm exact method names against
/// https://supabase.com/docs/reference/swift/introduction before assuming
/// this compiles as-is — client library APIs shift between versions.
final class CapsuleRepository {
    static let shared = CapsuleRepository()
    private init() {}

    #if canImport(Supabase)
    private var client: SupabaseClient { OrbitSupabase.client }

    func createCapsule(_ capsule: Capsule) async throws {
        try await client.from("capsules").insert(capsule).execute()
    }

    func updateStatus(capsuleId: UUID, to status: CapsuleStatus, timestampColumn: String? = nil) async throws {
        var values: [String: AnyJSON] = ["status": .string(status.rawValue)]
        if let timestampColumn {
            values[timestampColumn] = .string(ISO8601DateFormatter().string(from: Date()))
        }
        try await client.from("capsules").update(values).eq("id", value: capsuleId).execute()
    }

    func fetchCapsule(id: UUID) async throws -> Capsule {
        try await client.from("capsules").select().eq("id", value: id).single().execute().value
    }

    /// One-time fetch of everything involving this user (sent or received).
    /// Postgres' `or()` filter handles both sides in a single query — no
    /// need for Firestore's two-listeners-merged workaround.
    func fetchCapsules(involvingUserId userId: UUID) async throws -> [Capsule] {
        try await client.from("capsules")
            .select()
            .or("sender_id.eq.\(userId),recipient_id.eq.\(userId)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Live updates for a user's inbox. Call `.unsubscribe()` on the
    /// returned channel when the owning view disappears.
    func subscribeToCapsules(involvingUserId userId: UUID, onChange: @escaping ([Capsule]) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("capsules-\(userId)")
        // The change stream must be created before subscribe() is called —
        // previously these ran in two racing Tasks, so subscribe() could win
        // and Realtime would never deliver a single event.
        let changes = channel.postgresChange(AnyAction.self, table: "capsules")
        Task {
            do { try await channel.subscribeWithError() } catch { return }
            for await _ in changes {
                if let capsules = try? await fetchCapsules(involvingUserId: userId) {
                    onChange(capsules)
                }
            }
        }
        return channel
    }
    #endif
}
