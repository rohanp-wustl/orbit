import UIKit
#if canImport(Supabase)
import Supabase
#endif

/// A photo that's been resized and is ready to upload + send to Ground Control.
nonisolated struct PreparedPhoto: Sendable {
    /// Also the media_assets row id, and what LayoutItem.media stores.
    let mediaId: String
    let image: UIImage
    /// ~1600px JPEG — what gets stored and shown to the recipient.
    let uploadData: Data
    /// ~512px JPEG, base64 — only for the Gemini call, never stored.
    let thumbnailBase64: String
}

/// Uploads photos to Supabase Storage and loads them back for rendering.
///
/// Files live at `media/<sender uid>/<media id>.jpg` in a private bucket
/// (see docs/STAGE3_MIGRATION.sql). Because the path is derived from the
/// capsule's senderId + the LayoutItem's media id, the recipient can load a
/// photo without needing read access to the sender's media_assets rows.
final class MediaRepository {
    static let shared = MediaRepository()
    private init() {}

    private static let bucket = "media"
    /// In-memory only — freshly picked photos go in here so the editor never
    /// waits on a round trip for images that are already on this phone.
    private var cache: [String: UIImage] = [:]

    /// Resizes off the main thread so picking 4 photos doesn't stutter the UI.
    @concurrent
    static func prepare(_ data: Data) async -> PreparedPhoto? {
        guard let original = UIImage(data: data) else { return nil }
        let full = original.resized(maxDimension: 1600)
        let thumb = original.resized(maxDimension: 512)
        guard let uploadData = full.jpegData(compressionQuality: 0.8),
              let thumbData = thumb.jpegData(compressionQuality: 0.6) else { return nil }
        return PreparedPhoto(
            mediaId: UUID().uuidString.lowercased(),
            image: full,
            uploadData: uploadData,
            thumbnailBase64: thumbData.base64EncodedString()
        )
    }

    /// Storage path for a media id. Lowercased because Postgres renders
    /// auth.uid() lowercase, and the upload policy compares the folder
    /// name against it as text. Photos are .jpg, voice notes .m4a, video .mov.
    static func storagePath(mediaId: String, senderId: UUID, ext: String = "jpg") -> String {
        "\(senderId.uuidString.lowercased())/\(mediaId).\(ext)"
    }

    static func fileExtension(for type: LayoutItemType) -> String {
        switch type {
        case .audio: "m4a"
        case .video: "mov"
        default: "jpg"
        }
    }

    /// Downloaded voice notes/videos, keyed by media id → local file.
    private var fileCache: [String: URL] = [:]

    #if canImport(Supabase)
    private var client: SupabaseClient { OrbitSupabase.client }

    func upload(_ photo: PreparedPhoto, senderId: UUID) async throws {
        cache[photo.mediaId] = photo.image
        let path = Self.storagePath(mediaId: photo.mediaId, senderId: senderId)
        try await client.storage.from(Self.bucket)
            .upload(path, data: photo.uploadData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        if let id = UUID(uuidString: photo.mediaId) {
            let row = MediaAsset(id: id, type: .photo, storagePath: path, uploadedBy: senderId)
            try await client.from("media_assets").insert(row).execute()
        }
    }

    /// Uploads a voice note or video file and records its media_assets row.
    /// The local file is remembered so the sender's own editor never
    /// re-downloads what's already on the phone.
    func uploadFile(at localURL: URL, mediaId: String, type: MediaAssetType, senderId: UUID, transcript: String? = nil) async throws {
        let layoutType: LayoutItemType = type == .audio ? .audio : .video
        let ext = Self.fileExtension(for: layoutType)
        fileCache[mediaId] = localURL
        let data = try Data(contentsOf: localURL)
        let path = Self.storagePath(mediaId: mediaId, senderId: senderId, ext: ext)
        try await client.storage.from(Self.bucket)
            .upload(path, data: data, options: FileOptions(contentType: type == .audio ? "audio/mp4" : "video/quicktime", upsert: true))
        if let id = UUID(uuidString: mediaId) {
            let row = MediaAsset(id: id, type: type, storagePath: path, transcript: transcript, uploadedBy: senderId)
            try await client.from("media_assets").insert(row).execute()
        }
    }

    /// A local file for a voice note/video (downloaded once, then cached).
    func localFile(mediaId: String, senderId: UUID, type: LayoutItemType) async -> URL? {
        if let cached = fileCache[mediaId] { return cached }
        let ext = Self.fileExtension(for: type)
        let path = Self.storagePath(mediaId: mediaId, senderId: senderId, ext: ext)
        guard let data = try? await client.storage.from(Self.bucket).download(path: path) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(mediaId).\(ext)")
        guard (try? data.write(to: url)) != nil else { return nil }
        fileCache[mediaId] = url
        return url
    }

    /// The image for a LayoutItem's media id, from cache or Storage.
    func image(mediaId: String, senderId: UUID) async -> UIImage? {
        if let cached = cache[mediaId] { return cached }
        let path = Self.storagePath(mediaId: mediaId, senderId: senderId)
        guard let data = try? await client.storage.from(Self.bucket).download(path: path),
              let image = UIImage(data: data) else { return nil }
        cache[mediaId] = image
        return image
    }
    #else
    func image(mediaId: String, senderId: UUID) async -> UIImage? { cache[mediaId] }
    func localFile(mediaId: String, senderId: UUID, type: LayoutItemType) async -> URL? { fileCache[mediaId] }
    #endif

    /// Synchronous cache peek, so a page can draw already-loaded photos on its
    /// first frame (needed for the launch snapshot sent to iMessage).
    func cachedImage(_ mediaId: String?) -> UIImage? {
        mediaId.flatMap { cache[$0] }
    }

    #if canImport(Supabase)
    /// Uploads the rendered page snapshot that Ground Control texts to
    /// iMessage recipients. Returns its storage path (capsules.preview_image_path).
    func uploadPreview(_ png: Data, capsuleId: UUID, senderId: UUID) async throws -> String {
        let path = "\(senderId.uuidString.lowercased())/preview_\(capsuleId.uuidString.lowercased()).png"
        try await client.storage.from(Self.bucket)
            .upload(path, data: png, options: FileOptions(contentType: "image/png", upsert: true))
        return path
    }
    #endif

    /// Lets the offline demo and the builder show a picked video's poster
    /// frame / a recorded note without any upload.
    func remember(image: UIImage, for mediaId: String) { cache[mediaId] = image }
    func remember(file: URL, for mediaId: String) { fileCache[mediaId] = file }
}

private extension UIImage {
    nonisolated func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
