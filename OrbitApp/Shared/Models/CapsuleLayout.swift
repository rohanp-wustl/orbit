import Foundation

/// The full page description: what Ground Control returns, and what the editor
/// canvas reads and writes back. See docs/AI_CONTRACT.md for the JSON schema
/// this must satisfy, and for two worked examples.
struct CapsuleLayout: Codable, Equatable {
    var background: String   // asset name from the catalog, e.g. "kraft_paper_02"
    var template: String     // one of the 4-6 offered templates, e.g. "polaroid_scatter"
    var items: [LayoutItem]
    /// OrbitHue name the sender picked on the Create screen — the color of
    /// the package the recipient sees. Optional so older capsules (and
    /// Ground Control's output, which never sets it) still decode. Lives in
    /// the existing `layout` jsonb column, so no migration is needed.
    var packageColor: String? = nil

    /// A safe, always-valid layout used when the AI call fails or returns
    /// something that doesn't pass validation. Keep this in sync with whatever
    /// your default template/background assets are actually named.
    static func fallback(mediaIds: [String]) -> CapsuleLayout {
        let items: [LayoutItem] = mediaIds.enumerated().map { index, mediaId in
            LayoutItem(
                id: "fallback_\(index)",
                type: .photo,
                media: mediaId,
                x: 0.5,
                y: Double(0.2 + (Double(index) * 0.18)),
                w: 0.5,
                rotation: 0,
                z: index + 1,
                frame: "polaroid"
            )
        }
        return CapsuleLayout(background: "kraft_paper_02", template: "polaroid_scatter", items: items)
    }
}
