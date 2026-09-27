import Foundation

/// The hand-made asset library Ground Control is allowed to choose from.
/// Every name here is a string the AI may return in a CapsuleLayout, and
/// CapsulePageView knows how to draw each one. There are no image files
/// yet, so backgrounds/stickers/frames are drawn in code from the theme
/// palette — when Design delivers real art, add image sets with these same
/// names and swap the drawing in CapsulePageView; nothing else changes.
///
/// Keep descriptions concrete and mood-focused: they're the only thing the
/// model sees when picking.
enum OrbitAssets {
    static let backgrounds: [AssetCatalogEntry] = [
        .init(name: "kraft_paper_02", kind: "background", description: "warm brown kraft paper — cozy, handmade, the safe default"),
        .init(name: "night_sky", kind: "background", description: "deep navy with scattered stars — dreamy, missing someone far away"),
        .init(name: "sunset_wash", kind: "background", description: "soft pink-to-gold wash — celebratory, birthdays, good news"),
        .init(name: "mint_grid", kind: "background", description: "pale seafoam graph paper — playful, school/study, silly energy"),
    ]

    static let templates: [AssetCatalogEntry] = [
        .init(name: "polaroid_scatter", kind: "template", description: "photos tossed loosely at slight angles (-12 to 12 degrees), casual and warm"),
        .init(name: "clean_grid", kind: "template", description: "photos in a tidy 2-column grid with no rotation, calm and neat"),
        .init(name: "scrapbook_collage", kind: "template", description: "overlapping photos plus 2-4 stickers, busy and fun"),
        .init(name: "single_hero", kind: "template", description: "one large photo (w about 0.8) near the top with a caption beneath — for one important image"),
    ]

    static let stickers: [AssetCatalogEntry] = [
        .init(name: "star", kind: "sticker", description: "gold star"),
        .init(name: "heart", kind: "sticker", description: "magenta heart"),
        .init(name: "rocket", kind: "sticker", description: "little rocket — on-theme for Orbit"),
        .init(name: "planet", kind: "sticker", description: "ringed planet"),
        .init(name: "sparkle", kind: "sticker", description: "sparkles — excitement"),
        .init(name: "sun", kind: "sticker", description: "sun — summer, good mood"),
        .init(name: "moon", kind: "sticker", description: "crescent moon — night, sleep, time zones"),
        .init(name: "music_note", kind: "sticker", description: "music notes — songs, concerts, voice memos"),
        .init(name: "coffee", kind: "sticker", description: "coffee cup — mornings, cafes, study sessions"),
        .init(name: "paw", kind: "sticker", description: "paw print — pets"),
        .init(name: "beach", kind: "sticker", description: "hand-drawn palm tree, beach ball and sun — summer, trips, vacations"),
    ]

    static let fonts: [AssetCatalogEntry] = [
        .init(name: "handwritten", kind: "font", description: "casual handwriting — the default for captions"),
        .init(name: "marker", kind: "font", description: "bold rounded marker — short, loud captions"),
        .init(name: "typewriter", kind: "font", description: "typewriter — dry or deadpan captions"),
    ]

    static let frames: [AssetCatalogEntry] = [
        .init(name: "polaroid", kind: "frame", description: "white instant-photo border with a thick bottom"),
        .init(name: "tape", kind: "frame", description: "a strip of tape across the top edge"),
        .init(name: "plain", kind: "frame", description: "no border, just the photo with rounded corners"),
    ]

    /// Everything, in the shape GenerateLayoutRequest.assetCatalog wants.
    static let catalog: [AssetCatalogEntry] = backgrounds + templates + stickers + fonts + frames
}

/// Real placement for each template: Ground Control is told these slots and
/// adjusts them (the roadmap: "offer 4–6 templates to choose from and
/// adjust, rather than free placement"), and the offline fallback fills them
/// directly — so templates mean the same thing to the AI and the app.
struct TemplateSlot {
    let x: Double, y: Double, w: Double, rotation: Double
}

struct PageTemplate {
    let name: String
    let photos: [TemplateSlot]      // photo/video slots, in order
    let words: [TemplateSlot]       // captions, letter, question, song, recipe
    let stickers: [TemplateSlot]
    let audio: TemplateSlot

    static let all: [PageTemplate] = [
        PageTemplate(
            name: "polaroid_scatter",
            photos: [.init(x: 0.3, y: 0.22, w: 0.44, rotation: -7), .init(x: 0.7, y: 0.36, w: 0.4, rotation: 6),
                     .init(x: 0.32, y: 0.55, w: 0.38, rotation: 4), .init(x: 0.7, y: 0.68, w: 0.36, rotation: -5)],
            words: [.init(x: 0.5, y: 0.84, w: 0.8, rotation: -2), .init(x: 0.72, y: 0.12, w: 0.44, rotation: 3),
                    .init(x: 0.3, y: 0.76, w: 0.44, rotation: -3), .init(x: 0.7, y: 0.52, w: 0.4, rotation: 2)],
            stickers: [.init(x: 0.88, y: 0.1, w: 0.14, rotation: 12), .init(x: 0.1, y: 0.42, w: 0.13, rotation: -10),
                       .init(x: 0.9, y: 0.9, w: 0.13, rotation: 8)],
            audio: .init(x: 0.24, y: 0.92, w: 0.34, rotation: -4)),
        PageTemplate(
            name: "clean_grid",
            photos: [.init(x: 0.28, y: 0.22, w: 0.4, rotation: 0), .init(x: 0.72, y: 0.22, w: 0.4, rotation: 0),
                     .init(x: 0.28, y: 0.5, w: 0.4, rotation: 0), .init(x: 0.72, y: 0.5, w: 0.4, rotation: 0)],
            words: [.init(x: 0.5, y: 0.76, w: 0.84, rotation: 0), .init(x: 0.5, y: 0.07, w: 0.8, rotation: 0),
                    .init(x: 0.28, y: 0.9, w: 0.4, rotation: 0), .init(x: 0.72, y: 0.9, w: 0.4, rotation: 0)],
            stickers: [.init(x: 0.92, y: 0.07, w: 0.1, rotation: 0), .init(x: 0.08, y: 0.07, w: 0.1, rotation: 0)],
            audio: .init(x: 0.5, y: 0.92, w: 0.34, rotation: 0)),
        PageTemplate(
            name: "scrapbook_collage",
            photos: [.init(x: 0.36, y: 0.26, w: 0.52, rotation: -4), .init(x: 0.72, y: 0.44, w: 0.4, rotation: 8),
                     .init(x: 0.28, y: 0.6, w: 0.36, rotation: -9), .init(x: 0.66, y: 0.74, w: 0.34, rotation: 5)],
            words: [.init(x: 0.36, y: 0.84, w: 0.6, rotation: -3), .init(x: 0.74, y: 0.14, w: 0.4, rotation: 5),
                    .init(x: 0.3, y: 0.44, w: 0.34, rotation: -6), .init(x: 0.74, y: 0.9, w: 0.38, rotation: 3)],
            stickers: [.init(x: 0.14, y: 0.12, w: 0.16, rotation: -12), .init(x: 0.88, y: 0.3, w: 0.14, rotation: 14),
                       .init(x: 0.12, y: 0.78, w: 0.14, rotation: 8), .init(x: 0.52, y: 0.52, w: 0.12, rotation: -6)],
            audio: .init(x: 0.76, y: 0.6, w: 0.3, rotation: 6)),
        PageTemplate(
            name: "single_hero",
            photos: [.init(x: 0.5, y: 0.3, w: 0.78, rotation: -2), .init(x: 0.22, y: 0.66, w: 0.3, rotation: -6),
                     .init(x: 0.78, y: 0.66, w: 0.3, rotation: 6), .init(x: 0.5, y: 0.7, w: 0.3, rotation: 2)],
            words: [.init(x: 0.5, y: 0.62, w: 0.82, rotation: 0), .init(x: 0.5, y: 0.84, w: 0.8, rotation: -1),
                    .init(x: 0.5, y: 0.06, w: 0.7, rotation: 0), .init(x: 0.5, y: 0.94, w: 0.6, rotation: 0)],
            stickers: [.init(x: 0.86, y: 0.1, w: 0.14, rotation: 10), .init(x: 0.14, y: 0.52, w: 0.12, rotation: -8)],
            audio: .init(x: 0.5, y: 0.8, w: 0.34, rotation: 0)),
    ]

    /// Unknown names fall back to polaroid_scatter (the first entry).
    static func named(_ name: String) -> PageTemplate {
        all.first { $0.name == name } ?? all[0]
    }

    /// Slot guide for the prompt, e.g. "photos (0.30,0.22,w0.44,-7°) …".
    var promptDescription: String {
        func list(_ slots: [TemplateSlot]) -> String {
            slots.map { String(format: "(%.2f,%.2f,w%.2f,%.0f°)", $0.x, $0.y, $0.w, $0.rotation) }.joined(separator: " ")
        }
        return "\(name): photo slots \(list(photos)); word slots \(list(words)); sticker slots \(list(stickers))"
    }
}
