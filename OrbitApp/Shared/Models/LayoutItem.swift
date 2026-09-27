import Foundation

/// Every kind of thing that can go in a capsule. See docs/AI_SPEC.md for
/// per-capsule limits and which of these Ground Control may write.
enum LayoutItemType: String, Codable, CaseIterable {
    // The sender's own media — Ground Control can only place these, never make them.
    case photo, video, audio
    // Words. Ground Control may draft these from the sender's notes; always editable.
    case text        // short caption
    case letter      // a short note, rendered as a paper card
    case question    // a question for the recipient to answer (invites a reply capsule)
    case song        // a song suggestion: title + artist, links out (never the audio itself)
    case recipe      // a recipe card — only ever transcribed from the sender's notes, never invented
    // Decoration from the team's hand-made asset library.
    case sticker

    /// Items whose words Ground Control can draft/redo, shown as editable cards.
    var isWords: Bool {
        switch self {
        case .text, .letter, .question, .song, .recipe: true
        default: false
        }
    }

    var displayName: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        case .audio: "Voice note"
        case .text: "Caption"
        case .letter: "Letter"
        case .question: "Question"
        case .song: "Song"
        case .recipe: "Recipe card"
        case .sticker: "Sticker"
        }
    }

    /// Max of this type in one capsule (docs/AI_SPEC.md "Limits").
    var limit: Int {
        switch self {
        case .photo: 4
        case .video: 1
        case .audio: 2
        case .text: 3
        case .letter: 1
        case .question: 1
        case .song: 2
        case .recipe: 1
        case .sticker: 5
        }
    }
}

/// One placed element on a capsule page. This is the exact shape Ground Control's
/// JSON must produce, and the exact shape the canvas editor reads and writes back —
/// AI-made and hand-made capsules are the same data (see spec §1).
///
/// `x`, `y` are the item's CENTER and `w` its width, as fractions 0...1 of a
/// 3:4 page, so layouts scale to any screen. Custom Codable because several
/// fields exist only for some item types and should default rather than
/// fail to decode (older capsules predate the newer item types).
struct LayoutItem: Codable, Identifiable, Equatable {
    var id: String
    var type: LayoutItemType

    // .photo / .video / .audio — a media_assets id.
    var media: String?

    // .text / .letter / .question body; .song and .recipe use title/lines.
    var text: String?
    var font: String?

    // .sticker
    var asset: String?

    // .song title / .recipe name
    var title: String?
    // .song artist
    var artist: String?
    // .recipe ingredients + steps, one per line
    var lines: [String]?

    // Placement — required for every item type
    var x: Double
    var y: Double
    var w: Double
    var rotation: Double
    var z: Int

    // .photo only
    var frame: String?

    /// True when Ground Control drafted these words (so the builder can show
    /// them as editable cards). Cleared when the sender edits the item.
    var aiDrafted: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, media, text, font, asset, title, artist, lines, x, y, w, rotation, z, frame, aiDrafted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(LayoutItemType.self, forKey: .type)
        media = try c.decodeIfPresent(String.self, forKey: .media)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        font = try c.decodeIfPresent(String.self, forKey: .font)
        asset = try c.decodeIfPresent(String.self, forKey: .asset)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist)
        lines = try c.decodeIfPresent([String].self, forKey: .lines)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        w = try c.decode(Double.self, forKey: .w)
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        z = try c.decodeIfPresent(Int.self, forKey: .z) ?? 1
        frame = try c.decodeIfPresent(String.self, forKey: .frame)
        aiDrafted = try c.decodeIfPresent(Bool.self, forKey: .aiDrafted) ?? false
    }

    /// Memberwise init for building items in code (editor "add" actions,
    /// previews, the fallback layout).
    init(id: String, type: LayoutItemType, media: String? = nil, text: String? = nil,
         font: String? = nil, asset: String? = nil, title: String? = nil, artist: String? = nil,
         lines: [String]? = nil, x: Double, y: Double, w: Double,
         rotation: Double = 0, z: Int = 1, frame: String? = nil, aiDrafted: Bool = false) {
        self.id = id
        self.type = type
        self.media = media
        self.text = text
        self.font = font
        self.asset = asset
        self.title = title
        self.artist = artist
        self.lines = lines
        self.x = x
        self.y = y
        self.w = w
        self.rotation = rotation
        self.z = z
        self.frame = frame
        self.aiDrafted = aiDrafted
    }

    /// All the words in this item, for tone checks (banned phrases, length).
    var allWords: String {
        ([text, title, artist] + (lines ?? []).map(Optional.some)).compactMap { $0 }.joined(separator: " ")
    }

    /// Apple Music search link for a song suggestion — we link out, never
    /// host or upload the song (copyright).
    var songURL: URL? {
        guard type == .song, let title else { return nil }
        let query = [title, artist].compactMap { $0 }.joined(separator: " ")
        var components = URLComponents(string: "https://music.apple.com/us/search")
        components?.queryItems = [URLQueryItem(name: "term", value: query)]
        return components?.url
    }
}
