import Foundation

/// Mirrors the `crew_links` table in Postgres. Connects exactly two users;
/// created via an invite code (no contact syncing — matches the original
/// product spec). Two fixed columns (`userA`/`userB`) instead of an array,
/// since Postgres has no first-class equivalent of Firestore's array-of-ids
/// pattern that's still easy to query — `or()` filters on two plain columns
/// are simpler than an array-contains check.
struct CrewLink: Codable, Identifiable, Equatable {
    var id: UUID
    var userA: UUID
    /// nil while the invite is still open (nobody has joined with the code
    /// yet) — see docs/STAGE2_MIGRATION.sql.
    var userB: UUID?
    var inviteCode: String
    var createdAt: Date

    var isPending: Bool { userB == nil }

    init(id: UUID = UUID(), userA: UUID, userB: UUID? = nil, inviteCode: String, createdAt: Date = Date()) {
        self.id = id
        self.userA = userA
        self.userB = userB
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }

    /// Given "my" user id, returns the other person's id.
    func otherUserId(than myUserId: UUID) -> UUID? {
        if userA == myUserId { return userB }
        if userB == myUserId { return userA }
        return nil
    }
}

/// Mirrors `imessage_invites` (docs/STAGE5_MIGRATION.sql): the app's request
/// for Ground Control to add someone to the crew by phone. The agent server
/// picks it up, texts them, and flips `status` to sent/failed — or `waiting`
/// when Photon's shared line needs them to text `line` once first (STAGE5B).
struct IMessageInvite: Codable, Identifiable, Equatable {
    enum Status: String, Codable { case pending, waiting, sent, failed }

    var id: UUID
    var inviterId: UUID
    var displayName: String
    var phone: String
    var status: Status
    var error: String?
    /// Ground Control's number for this person; they text it "hi" to join.
    var line: String?
    var createdAt: Date

    /// "+16282688640" → "(628) 268-8640" for US numbers.
    var formattedLine: String? {
        guard let line else { return nil }
        let digits = line.filter(\.isNumber)
        guard digits.count == 11, digits.hasPrefix("1") else { return line }
        let d = Array(digits.dropFirst())
        return "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6..<10]))"
    }

    init(id: UUID = UUID(), inviterId: UUID, displayName: String, phone: String,
         status: Status = .pending, error: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.inviterId = inviterId
        self.displayName = displayName
        self.phone = phone
        self.status = status
        self.error = error
        self.createdAt = createdAt
    }

    /// Same normalization as the agent (agent/src/orbit.ts normalizePhone).
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("@") { return trimmed.lowercased() }
        let digits = trimmed.filter(\.isNumber)
        if trimmed.hasPrefix("+") { return "+" + digits }
        if digits.count == 10 { return "+1" + digits }
        if digits.count == 11, digits.hasPrefix("1") { return "+" + digits }
        return "+" + digits
    }
}
