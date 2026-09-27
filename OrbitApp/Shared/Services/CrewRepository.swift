import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// Everything about who's connected to whom: creating an invite code,
/// joining one, and looking up display names. Requires
/// docs/STAGE2_MIGRATION.sql to have been run (nullable user_b + the
/// join_crew function).
final class CrewRepository {
    static let shared = CrewRepository()
    private init() {}

    #if canImport(Supabase)
    private var client: SupabaseClient { OrbitSupabase.client }

    /// The signed-in user's profile, if a previous launch already created
    /// one — lets the app skip onboarding instead of minting a brand-new
    /// anonymous account every launch. supabase-swift keeps the session in
    /// the keychain on its own; this just reconnects it to the profile row.
    func restoreSignedInUser() async -> AppUser? {
        guard let session = try? await client.auth.session else { return nil }
        return try? await client.from("profiles")
            .select()
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
    }

    /// Every crew link this user is part of — both joined links and their
    /// own still-open invites.
    func fetchCrewLinks(for userId: UUID) async throws -> [CrewLink] {
        try await client.from("crew_links")
            .select()
            .or("user_a.eq.\(userId),user_b.eq.\(userId)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Creates an open invite (user_b empty) with a short code to share.
    func createInvite(for userId: UUID) async throws -> CrewLink {
        let link = CrewLink(userA: userId, inviteCode: Self.makeInviteCode())
        try await client.from("crew_links").insert(link).execute()
        return link
    }

    /// Claims someone else's open invite. Returns nil if the code is wrong,
    /// already used, or your own.
    func joinCrew(code: String) async throws -> CrewLink? {
        let joined: [CrewLink] = try await client
            .rpc("join_crew", params: ["code": code])
            .execute()
            .value
        return joined.first
    }

    /// Display names for a set of user ids, keyed by id.
    func fetchProfiles(ids: [UUID]) async throws -> [UUID: AppUser] {
        guard !ids.isEmpty else { return [:] }
        let profiles: [AppUser] = try await client.from("profiles")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    // MARK: - iMessage (docs/PHOTON.md)

    /// Asks Ground Control (the agent server) to add someone by phone. They
    /// get capsules in iMessage and can reply there — no app needed.
    func inviteByIMessage(name: String, phone: String, inviterId: UUID) async throws -> IMessageInvite {
        let invite = IMessageInvite(inviterId: inviterId, displayName: name, phone: phone)
        try await client.from("imessage_invites").insert(invite).execute()
        return invite
    }

    func fetchIMessageInvites(for inviterId: UUID) async throws -> [IMessageInvite] {
        try await client.from("imessage_invites")
            .select()
            .eq("inviter_id", value: inviterId.uuidString)
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
            .value
    }

    /// Saves the signed-in user's phone + "also text me" preference.
    func updateIMessageSettings(userId: UUID, phone: String?, textMe: Bool) async throws {
        struct Update: Encodable { let phone: String?; let imessageUpdates: Bool }
        try await client.from("profiles")
            .update(Update(phone: phone, imessageUpdates: textMe))
            .eq("id", value: userId.uuidString)
            .execute()
    }

    /// Fires `onChange` whenever a crew link involving this user changes —
    /// e.g. someone just joined your invite. Call `.unsubscribe()` on the
    /// returned channel when done.
    func subscribeToCrewLinks(for userId: UUID, onChange: @escaping ([CrewLink]) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("crew-links-\(userId)")
        // The change stream must be created before subscribe() is called,
        // or Realtime never registers interest in the table.
        let changes = channel.postgresChange(AnyAction.self, table: "crew_links")
        Task {
            do { try await channel.subscribeWithError() } catch { return }
            for await _ in changes {
                if let links = try? await fetchCrewLinks(for: userId) {
                    onChange(links)
                }
            }
        }
        return channel
    }
    #endif

    /// 6 characters, skipping look-alikes (0/O, 1/I/L) so it's easy to read
    /// out loud across a table.
    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }
}
