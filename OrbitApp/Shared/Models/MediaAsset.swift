import Foundation

enum MediaAssetType: String, Codable {
    case photo, video, audio
}

/// Mirrors the `media_assets` table in Postgres; the actual file lives in
/// Supabase Storage at `storagePath`, not in this row. A `LayoutItem.media`
/// field stores just this row's `id` — the AI never sees or returns full
/// asset objects, only ids (see Shared/Services/GroundControlService.swift).
struct MediaAsset: Codable, Identifiable, Equatable {
    var id: UUID
    var type: MediaAssetType
    var storagePath: String
    /// On-device Speech-framework transcript, audio only. Sent to the AI as
    /// text context so Ground Control can write captions that reference
    /// what was actually said.
    var transcript: String?
    var uploadedBy: UUID
    var createdAt: Date

    init(id: UUID = UUID(), type: MediaAssetType, storagePath: String,
         transcript: String? = nil, uploadedBy: UUID, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.storagePath = storagePath
        self.transcript = transcript
        self.uploadedBy = uploadedBy
        self.createdAt = createdAt
    }
}
