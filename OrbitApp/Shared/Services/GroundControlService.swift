import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// One item of context the app sends about the sender's media. Ground
/// Control sees a small thumbnail per photo, ONE still frame + the length
/// per video, and an on-device transcript per voice note — never the full
/// files (docs/AI_SPEC.md "Inputs").
struct MediaContext {
    var mediaId: String
    var kind: String // "photo" | "video" | "audio"
    var thumbnailBase64: String? // photos + video poster frame
    var transcript: String?      // voice notes
    var durationSeconds: Double? // video + voice notes
}

/// One entry the app offers from its hand-made asset library.
struct AssetCatalogEntry {
    var name: String
    var kind: String // "background" | "template" | "sticker" | "font" | "frame"
    var description: String
}

struct GenerateLayoutRequest {
    var senderName: String
    var recipientName: String
    var occasion: String
    var mood: String
    var crewNotes: String
    var media: [MediaContext]
    var assetCatalog: [AssetCatalogEntry]
}

enum GroundControlError: Error {
    case badResponse
    case missingAPIKey
    /// 429/500/503 — try the next model.
    case overloaded
}

/// Ground Control: turns the sender's own media + notes into a scrapbook
/// layout (JSON). It never generates images; its words are drafted only
/// from what the sender wrote, and every one is editable/redoable. Full
/// spec — inputs, outputs, tone, limits, privacy, examples, failure
/// handling — lives in docs/AI_SPEC.md; this file is the source of truth
/// for the exact prompt and schema.
///
/// Transport: if `Secrets.useGroundControlFunction` is on, requests go to
/// the Supabase Edge Function (supabase/functions/ground-control), which
/// holds the Gemini key server-side. Otherwise the app calls Gemini
/// directly (demo-only fallback; see docs/SERVER_SETUP.md).
enum GroundControlService {
    /// Tried in order. The test-set run (docs/AI_TEST_SET.md) hit 503 "high
    /// demand" on the primary model for most calls, so an overloaded or slow
    /// model hands off to the next instead of dropping to the fallback layout.
    static let models = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash-lite"]
    /// Per-attempt cap, so a hung call can't strand the packing screen.
    static let attemptTimeout: TimeInterval = 20

    /// Hard budget for the whole AI step (target < 10 s; worst case this).
    static let totalBudget: TimeInterval = 28

    /// Validate → retry once → salvage → fallback (docs/AI_SPEC.md "Failure handling").
    static func generateLayout(for request: GenerateLayoutRequest) async -> (layout: CapsuleLayout, usedFallback: Bool) {
        let deadline = Date().addingTimeInterval(totalBudget)
        var best: CapsuleLayout?
        var correction: String?
        for attempt in 0..<2 {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 6 else { break }
            do {
                let raw = try await callGemini(request, correction: correction, deadline: deadline)
                let repaired = repair(raw, for: request)
                let errors = validateLayout(repaired, against: request)
                if errors.isEmpty { return (markDrafted(repaired), false) }
                print("Ground Control: attempt \(attempt + 1) invalid — \(errors)")
                best = repaired
                correction = errors.joined(separator: "; ")
            } catch {
                print("Ground Control: attempt \(attempt + 1) failed — \(error)")
                break
            }
        }
        // Salvage: drop only the offending word items rather than losing the
        // whole capsule to one bad caption.
        if let best {
            let salvaged = dropInvalidWords(best, for: request)
            if validateLayout(salvaged, against: request).isEmpty, !salvaged.items.isEmpty {
                return (markDrafted(salvaged), false)
            }
        }
        return (buildFallbackLayout(for: request), true)
    }

    /// Fixes cosmetic slips (common from the lite model under load) so they
    /// don't cost a whole retry: empty items, missing "?", unknown fonts or
    /// frames, wrong media type, forgotten media, over-limit items, dup ids.
    static func repair(_ layout: CapsuleLayout, for request: GenerateLayoutRequest) -> CapsuleLayout {
        var result = layout
        let catalog = request.assetCatalog
        let names = Set(catalog.map(\.name))
        let backgrounds = catalog.filter { $0.kind == "background" }.map(\.name)
        let templates = catalog.filter { $0.kind == "template" }.map(\.name)
        let fonts = Set(catalog.filter { $0.kind == "font" }.map(\.name))
        let frames = Set(catalog.filter { $0.kind == "frame" }.map(\.name))
        let mediaKinds = Dictionary(uniqueKeysWithValues: request.media.map { ($0.mediaId, $0.kind) })

        if !backgrounds.contains(result.background) { result.background = backgrounds.first ?? "kraft_paper_02" }
        if !templates.contains(result.template) { result.template = templates.first ?? "polaroid_scatter" }

        var seenIds = Set<String>()
        var placedMedia = Set<String>()
        var counts: [LayoutItemType: Int] = [:]
        var kept: [LayoutItem] = []
        for var item in result.items {
            // Media: must be a real id, placed once, typed by its real kind.
            if [.photo, .video, .audio].contains(item.type) {
                guard let media = item.media, let kind = mediaKinds[media], !placedMedia.contains(media),
                      let realType = LayoutItemType(rawValue: kind) else { continue }
                item.type = realType
                placedMedia.insert(media)
            }
            // Words: drop empties; tidy formatting.
            if item.type.isWords {
                item.text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                if item.type == .question, let text = item.text, !text.isEmpty, !text.hasSuffix("?") {
                    item.text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".!")) + "?"
                }
                if item.allWords.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                if item.type == .song, (item.title ?? "").isEmpty || (item.artist ?? "").isEmpty { continue }
                if item.type == .recipe, (item.lines ?? []).isEmpty { continue }
                if let font = item.font, !fonts.contains(font) { item.font = "handwritten" }
            }
            if item.type == .sticker, !names.contains(item.asset ?? "") { continue }
            if let frame = item.frame, !frames.contains(frame) { item.frame = item.type == .photo ? "polaroid" : nil }
            counts[item.type, default: 0] += 1
            if counts[item.type, default: 0] > item.type.limit { continue }
            if seenIds.contains(item.id) { item.id += "_\(kept.count)" }
            seenIds.insert(item.id)
            kept.append(item)
        }
        // Place any media the model forgot, into the template's free slots.
        let template = PageTemplate.named(result.template)
        var z = (kept.map(\.z).max() ?? 0) + 1
        var slotIndex = kept.filter { [.photo, .video].contains($0.type) }.count
        for media in request.media where !placedMedia.contains(media.mediaId) {
            guard let type = LayoutItemType(rawValue: media.kind) else { continue }
            let slot = type == .audio ? template.audio : template.photos[min(slotIndex, template.photos.count - 1)]
            if type != .audio { slotIndex += 1 }
            kept.append(LayoutItem(id: "placed_\(media.mediaId.prefix(6))", type: type, media: media.mediaId,
                                   x: slot.x, y: slot.y, w: slot.w, rotation: slot.rotation, z: z,
                                   frame: type == .photo ? "polaroid" : nil))
            z += 1
        }
        result.items = kept
        return result
    }

    /// Removes word items that still break tone/privacy rules.
    private static func dropInvalidWords(_ layout: CapsuleLayout, for request: GenerateLayoutRequest) -> CapsuleLayout {
        var result = layout
        result.items.removeAll { $0.type.isWords && !toneErrors(for: $0, notes: request.crewNotes).isEmpty }
        return result
    }

    /// "Ask Ground Control to redo this item": rewrites ONE word item
    /// (caption, letter, question, song) without touching the rest of the
    /// capsule. Keeps the item's id and position. Returns nil on failure,
    /// so the caller keeps the original.
    static func regenerate(_ item: LayoutItem, in layout: CapsuleLayout, for request: GenerateLayoutRequest) async -> LayoutItem? {
        guard item.type.isWords, item.type != .recipe else { return nil }
        let others = layout.items.filter { $0.id != item.id && $0.type.isWords }.map(\.allWords).joined(separator: " | ")
        let instruction = """
        Rewrite ONE \(item.type.rawValue) item for this capsule. Return a JSON object with only the fields for that item \
        (for a song: title and artist; otherwise: text). It must follow every voice, tone, length, and privacy rule. \
        Make it clearly different from the current version: "\(item.allWords)". \
        Don't repeat what the other items already say: \(others.isEmpty ? "(none)" : others)
        """
        let body = buildBody(userText: buildUserMessage(request, correction: nil) + "\n\n" + instruction,
                             media: [], schema: singleItemSchema)
        for _ in 0..<2 {
            guard let text = try? await send(body),
                  let fields = try? JSONDecoder().decode(RewriteFields.self, from: Data(text.utf8)) else { continue }
            var rewritten = item
            rewritten.text = fields.text ?? item.text
            rewritten.title = fields.title ?? item.title
            rewritten.artist = fields.artist ?? item.artist
            rewritten.aiDrafted = true
            if toneErrors(for: rewritten, notes: request.crewNotes).isEmpty && rewritten.allWords != item.allWords {
                return rewritten
            }
        }
        return nil
    }

    private struct RewriteFields: Decodable {
        var text: String?
        var title: String?
        var artist: String?
    }

    // MARK: - Network

    private static func callGemini(_ request: GenerateLayoutRequest, correction: String?, deadline: Date) async throws -> CapsuleLayout {
        let body = buildBody(userText: buildUserMessage(request, correction: correction),
                             media: request.media, schema: capsuleLayoutSchema)
        let text = try await send(body, deadline: deadline)
        var layout = try JSONDecoder().decode(CapsuleLayout.self, from: Data(text.utf8))
        // Nudge items that hang off the page edge back on, rather than
        // spending a whole ~10s retry on a cosmetic placement miss.
        for index in layout.items.indices {
            let halfWidth = min(layout.items[index].w, 1) / 2
            layout.items[index].x = min(max(layout.items[index].x, halfWidth), 1 - halfWidth)
        }
        return layout
    }

    private static func buildBody(userText: String, media: [MediaContext], schema: [String: Any]) -> [String: Any] {
        var parts: [[String: Any]] = [["text": userText]]
        for item in media {
            if let base64 = item.thumbnailBase64 {
                parts.append(["inlineData": ["mimeType": "image/jpeg", "data": base64]])
            }
        }
        return [
            "systemInstruction": ["parts": [["text": groundControlSystemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0.9,
            ],
        ]
    }

    /// Sends a Gemini generateContent body — via the Edge Function when
    /// configured (key server-side), else directly — and returns the
    /// model's JSON text.
    private static func send(_ body: [String: Any], deadline: Date = .now.addingTimeInterval(totalBudget)) async throws -> String {
        var lastError: Error = GroundControlError.badResponse
        for model in models {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 3 else { break }
            do {
                return try await send(body, model: model, timeout: min(attemptTimeout, remaining))
            } catch let error as URLError where error.code == .timedOut {
                lastError = error
            } catch GroundControlError.overloaded {
                lastError = GroundControlError.overloaded
            }
            print("Ground Control: \(model) busy/slow, trying the next model")
        }
        throw lastError
    }

    private static func send(_ body: [String: Any], model: String, timeout: TimeInterval) async throws -> String {
        var urlRequest: URLRequest
        var payload = body
        if Secrets.useGroundControlFunction {
            guard let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/ground-control") else { throw GroundControlError.badResponse }
            urlRequest = URLRequest(url: url)
            urlRequest.setValue("Bearer \(await accessToken())", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
            payload["model"] = model // the Edge Function reads this and strips it
        } else {
            guard !Secrets.geminiAPIKey.isEmpty else { throw GroundControlError.missingAPIKey }
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(Secrets.geminiAPIKey)") else {
                throw GroundControlError.badResponse
            }
            urlRequest = URLRequest(url: url)
        }
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let status = (response as? HTTPURLResponse)?.statusCode, [429, 500, 503].contains(status) {
            // 429 + "quota" = the free tier's daily allowance for this model is
            // used up (resets daily) — not an outage. Log it plainly.
            if status == 429, String(data: data, encoding: .utf8)?.contains("quota") == true {
                print("Ground Control: \(model) is out of free-tier quota for today")
            }
            throw GroundControlError.overloaded
        }
        // Skip any "thought" parts — only the final answer part is the JSON.
        guard
            let top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = top["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let responseParts = content["parts"] as? [[String: Any]],
            let text = responseParts.last(where: { $0["thought"] as? Bool != true })?["text"] as? String
        else {
            print("Ground Control: unexpected response — \(String(data: data, encoding: .utf8) ?? "")")
            throw GroundControlError.badResponse
        }
        return text
    }

    private static func accessToken() async -> String {
        #if canImport(Supabase)
        if let session = try? await OrbitSupabase.client.auth.session { return session.accessToken }
        #endif
        return Secrets.supabaseAnonKey
    }

    private static func buildUserMessage(_ request: GenerateLayoutRequest, correction: String?) -> String {
        let mediaLines = request.media.map { m -> String in
            switch m.kind {
            case "audio":
                let length = m.durationSeconds.map { String(format: " (%.0fs)", $0) } ?? ""
                return "- media id \"\(m.mediaId)\" (voice note\(length)): transcript: \"\(m.transcript ?? "(no transcript)")\""
            case "video":
                let length = m.durationSeconds.map { String(format: ", %.0fs long", $0) } ?? ""
                return "- media id \"\(m.mediaId)\" (video\(length)): [one still frame attached]"
            default:
                return "- media id \"\(m.mediaId)\" (photo): [thumbnail attached]"
            }
        }.joined(separator: "\n")
        let catalogLines = request.assetCatalog.map { "- \($0.kind) \"\($0.name)\": \($0.description)" }.joined(separator: "\n")
        let templateLines = PageTemplate.all.map { "- \($0.promptDescription)" }.joined(separator: "\n")
        var message = """
        From: \(request.senderName)
        To: \(request.recipientName)
        Occasion: \(request.occasion)
        Mood: \(request.mood)

        Sender's notes (the ONLY facts you may use):
        \(request.crewNotes.isEmpty ? "(none — keep words minimal and generic-free; prefer fewer, shorter captions)" : request.crewNotes)

        Sender's media:
        \(mediaLines.isEmpty ? "(none)" : mediaLines)

        Available assets:
        \(catalogLines)

        Template slots (x, y = item center; w = width; degrees). Pick one template and adjust these:
        \(templateLines)
        """
        if let correction {
            message += "\n\nYour previous attempt had problems: \(correction)\nFix them and resubmit."
        }
        return message
    }

    // MARK: - Validation (business rules JSONDecoder can't check on its own)

    private static func validateLayout(_ layout: CapsuleLayout, against request: GenerateLayoutRequest) -> [String] {
        var errors: [String] = []
        let mediaKinds = Dictionary(uniqueKeysWithValues: request.media.map { ($0.mediaId, $0.kind) })
        let assetNames = Set(request.assetCatalog.map(\.name))
        let backgroundNames = Set(request.assetCatalog.filter { $0.kind == "background" }.map(\.name))
        let templateNames = Set(request.assetCatalog.filter { $0.kind == "template" }.map(\.name))

        if !backgroundNames.contains(layout.background) {
            errors.append("background \"\(layout.background)\" is not in the offered catalog")
        }
        if !templateNames.contains(layout.template) {
            errors.append("template \"\(layout.template)\" is not in the offered catalog")
        }
        if layout.items.isEmpty {
            errors.append("items is empty")
            return errors
        }

        // Per-type limits (docs/AI_SPEC.md "Limits").
        for type in LayoutItemType.allCases {
            let count = layout.items.filter { $0.type == type }.count
            if count > type.limit { errors.append("too many \(type.rawValue) items (\(count), max \(type.limit))") }
        }

        var seenIds = Set<String>()
        var placedMediaIds = Set<String>()
        for item in layout.items {
            if seenIds.contains(item.id) { errors.append("duplicate item id \"\(item.id)\"") }
            seenIds.insert(item.id)

            for (label, value) in [("x", item.x), ("y", item.y), ("w", item.w)] where value < 0 || value > 1 {
                errors.append("item \(item.id): \(label) must be between 0 and 1, got \(value)")
            }

            switch item.type {
            case .photo, .video, .audio:
                if let media = item.media, let kind = mediaKinds[media] {
                    if kind != item.type.rawValue {
                        errors.append("item \(item.id): media \"\(media)\" is a \(kind), not a \(item.type.rawValue)")
                    }
                    placedMediaIds.insert(media)
                } else {
                    errors.append("item \(item.id): media \"\(item.media ?? "nil")\" was not one of the ids we sent")
                }
            case .sticker:
                if let asset = item.asset, !assetNames.contains(asset) { errors.append("item \(item.id): sticker asset \"\(asset)\" is not in the offered catalog") }
                else if item.asset == nil { errors.append("item \(item.id): sticker items require an asset name") }
            case .text, .letter, .question, .song, .recipe:
                errors += toneErrors(for: item, notes: request.crewNotes).map { "item \(item.id): \($0)" }
                if let font = item.font, !assetNames.contains(font) { errors.append("item \(item.id): font \"\(font)\" is not in the offered catalog") }
            }
            if let frame = item.frame, !assetNames.contains(frame) {
                errors.append("item \(item.id): frame \"\(frame)\" is not in the offered catalog")
            }
        }
        for mediaId in mediaKinds.keys where !placedMediaIds.contains(mediaId) {
            errors.append("media id \"\(mediaId)\" was uploaded but never placed in the layout")
        }
        return errors
    }

    /// Voice/tone/privacy checks for one word item — shared by full
    /// validation and single-item redo.
    static func toneErrors(for item: LayoutItem, notes: String) -> [String] {
        var errors: [String] = []
        let words = item.allWords
        let lower = words.lowercased()
        let wordCount = words.split(whereSeparator: \.isWhitespace).count

        for phrase in bannedPhrases where lower.contains(phrase) {
            errors.append("uses the banned phrase \"\(phrase)\"")
        }
        if lower.contains("as an ai") || lower.contains("ground control") {
            errors.append("must not mention AI or Ground Control")
        }
        // Privacy: never put contact details on a page.
        if words.range(of: #"\b\d{3}[-. )]*\d{3}[-. ]*\d{4}\b"#, options: .regularExpression) != nil
            || words.range(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.regularExpression, .caseInsensitive]) != nil {
            errors.append("contains a phone number or email address")
        }

        switch item.type {
        case .text:
            if words.isEmpty { errors.append("text items require text") }
            if wordCount > 14 { errors.append("captions must be 14 words or fewer (got \(wordCount))") }
        case .letter:
            if words.isEmpty { errors.append("letters require text") }
            if wordCount > 70 { errors.append("letters must be 70 words or fewer (got \(wordCount))") }
        case .question:
            if !(item.text ?? "").trimmingCharacters(in: .whitespaces).hasSuffix("?") { errors.append("a question must end with ?") }
            if wordCount > 20 { errors.append("questions must be 20 words or fewer") }
        case .song:
            if (item.title ?? "").isEmpty || (item.artist ?? "").isEmpty { errors.append("songs need both title and artist") }
        case .recipe:
            // Recipes are transcribed, never invented.
            let notesLower = notes.lowercased()
            if !["recipe", "ingredient", "cup", "tbsp", "tsp", "bake", "oven"].contains(where: notesLower.contains) {
                errors.append("recipe cards are only allowed when the sender's notes include a recipe — never invent one")
            }
            if (item.lines ?? []).isEmpty { errors.append("recipe cards need lines") }
        default:
            break
        }
        return errors
    }

    /// Stock phrases that make a capsule read like a greeting card or a bot
    /// (docs/AI_SPEC.md "Ban list"). Checked case-insensitively.
    static let bannedPhrases = [
        "i hope this finds you well", "hope this finds you", "cherish", "journey", "just wanted to say",
        "sending you love", "sending love", "thinking of you today", "hope you're doing well", "missing you lots",
        "sending hugs", "warm hugs", "treasure", "memories that last", "lifetime of memories", "near and far",
        "no matter the distance", "distance means", "special someone", "embark", "heartfelt", "from the bottom of my heart",
        "a testament to", "in this crazy world", "you mean the world",
    ]

    /// Items the sender will see as Ground Control drafts (editable cards).
    private static func markDrafted(_ layout: CapsuleLayout) -> CapsuleLayout {
        var copy = layout
        for index in copy.items.indices where copy.items[index].type.isWords {
            copy.items[index].aiDrafted = true
        }
        return copy
    }

    /// Always valid given whatever catalog was actually sent: fills the first
    /// offered template's real slots with the sender's media plus one neutral
    /// label. It deliberately does NOT paste the sender's notes onto the page:
    /// notes are written *about* the recipient, for Ground Control, and may
    /// contain private details (the test set's privacy case caught this).
    static func buildFallbackLayout(for request: GenerateLayoutRequest) -> CapsuleLayout {
        let background = request.assetCatalog.first { $0.kind == "background" }?.name ?? "kraft_paper_02"
        let templateName = request.assetCatalog.first { $0.kind == "template" }?.name ?? "polaroid_scatter"
        let template = PageTemplate.named(templateName)
        var items: [LayoutItem] = []
        var z = 1
        let visual = request.media.filter { $0.kind != "audio" }
        for (index, media) in visual.prefix(template.photos.count).enumerated() {
            let slot = template.photos[index]
            items.append(LayoutItem(id: "fallback_\(index)", type: media.kind == "video" ? .video : .photo,
                                    media: media.mediaId, x: slot.x, y: slot.y, w: slot.w, rotation: slot.rotation,
                                    z: z, frame: media.kind == "photo" ? "polaroid" : nil))
            z += 1
        }
        for (index, media) in request.media.filter({ $0.kind == "audio" }).prefix(1).enumerated() {
            let slot = template.audio
            items.append(LayoutItem(id: "fallback_audio_\(index)", type: .audio, media: media.mediaId,
                                    x: slot.x, y: slot.y, w: slot.w, rotation: slot.rotation, z: z))
            z += 1
        }
        if let slot = template.words.first {
            items.append(LayoutItem(id: "fallback_label", type: .text, text: "For \(request.recipientName), from \(request.senderName)",
                                    font: "handwritten", x: slot.x, y: slot.y, w: slot.w, rotation: slot.rotation, z: z))
        }
        return CapsuleLayout(background: background, template: templateName, items: items)
    }
}

// MARK: - System prompt (source of truth; docs/AI_SPEC.md explains it)

private let groundControlSystemPrompt = """
You are Ground Control. You help someone assemble a small scrapbook page (a "capsule") for a person they miss. You are the \
arranger, not the author: the sender's photos, videos, voice notes, and notes are the content. You choose a template and \
background, place every media item, add a few stickers, and draft a small amount of text IN THE SENDER'S VOICE, using only \
facts from their notes. The sender will edit or redo anything you write.

OUTPUT: exactly one JSON object matching the schema. No prose.

ITEM TYPES AND LIMITS (per capsule):
- photo (max 4), video (max 1), audio (voice note, max 2): the sender's media. Place EVERY media id exactly once, using the \
item type that matches the media's kind. Never invent media ids.
- text (max 3): short captions, 14 words or fewer each. Usually 1–3.
- letter (max 1): a short note from the sender, 70 words or fewer. Only if the notes give you enough to say something specific.
- question (max 1): one question for the recipient to answer, ending in "?". Grounded in the notes. It invites a reply capsule.
- song (max 2): a real, well-known song (title + artist). ONLY if the notes mention music, a song, an artist, or a memory tied \
to a song. Never lyrics.
- recipe (max 1): ONLY if the notes contain a recipe; transcribe it into "title" and short "lines". Never invent a recipe.
- sticker (max 5, usually 2–4): only asset names from the catalog.

VOICE AND TONE:
- Write as the sender talking to this one person — first person, casual, the way they'd actually say it out loud.
- Use their specific details: names, places, foods, jokes, pets, numbers. Specific beats sweet.
- Match the requested mood. Short. A little funny or a little tender. Never greeting-card.
- Never invent facts, events, dates, places, or feelings the sender didn't mention. If the notes are thin, write less.
- Never mention AI, Ground Control, or that anything was generated. No hashtags. At most one emoji in the whole capsule.
- Banned (never use, or close variants): "I hope this finds you well", "cherish", "journey", "just wanted to say", \
"sending you love", "thinking of you today", "hope you're doing well", "missing you lots", "sending hugs", "treasure", \
"memories that last a lifetime", "near and far", "no matter the distance", "special someone", "embark", "heartfelt", \
"from the bottom of my heart", "you mean the world".

PRIVACY: never include addresses, phone numbers, emails, last names, passwords, financial or medical details, or anything \
identifying about people in photos beyond what the sender wrote. Don't describe strangers in photos.

PLACEMENT: the page is 3:4 portrait. x and y are the CENTER of the item, as fractions of page width/height; w is width as a \
fraction of page width. Keep every item fully on the page (x - w/2 ≥ 0.03, x + w/2 ≤ 0.97). Start from one template's slots \
and adjust slightly; don't cover a photo's center with words or stickers. Give text items a font from the catalog, photos a \
frame from the catalog. Use z for stacking (stickers on top).

EXAMPLE 1
Input: From Priya, to Grandma Rose. Occasion: Birthday. Mood: Sweet. Notes: "Grandma turns 80 Saturday. Her lemon bars — 2 cups \
flour, 1 cup butter, 4 eggs, 2 lemons, bake 350 for 25 min. I still burn the crust. She always hums Moon River while baking." \
Media: p1 (photo: Priya and Grandma on a porch), a1 (voice note transcript: "Happy birthday Grandma, I tried the bars again").
Output:
{"background":"sunset_wash","template":"polaroid_scatter","items":[
{"id":"i1","type":"photo","media":"p1","x":0.32,"y":0.24,"w":0.46,"rotation":-6,"z":1,"frame":"polaroid"},
{"id":"i2","type":"text","text":"80 looks good on you, porch queen","font":"handwritten","x":0.72,"y":0.12,"w":0.44,"rotation":3,"z":2},
{"id":"i3","type":"recipe","title":"Grandma's Lemon Bars","lines":["2 cups flour","1 cup butter","4 eggs, 2 lemons","350° for 25 min","Do not burn the crust (I did)"],"x":0.7,"y":0.47,"w":0.46,"rotation":4,"z":3},
{"id":"i4","type":"audio","media":"a1","x":0.26,"y":0.56,"w":0.34,"rotation":-4,"z":4},
{"id":"i5","type":"song","title":"Moon River","artist":"Andy Williams","x":0.5,"y":0.74,"w":0.7,"rotation":-1,"z":5},
{"id":"i6","type":"question","text":"What's the secret to the crust? Asking for me.","font":"marker","x":0.5,"y":0.89,"w":0.72,"rotation":1,"z":6},
{"id":"i7","type":"sticker","asset":"heart","x":0.88,"y":0.3,"w":0.12,"rotation":12,"z":7}]}

EXAMPLE 2
Input: From Sam, to Jordan. Occasion: Miss you. Mood: Funny. Notes: "Jordan moved to Seattle in August. We split terrible 2am \
ramen at the 7-Eleven every Thursday. Our cat Miso still sits in their chair like she's waiting." Media: p1 (photo: cat on an \
empty chair), p2 (photo: cup ramen on a car dashboard).
Output:
{"background":"mint_grid","template":"scrapbook_collage","items":[
{"id":"i1","type":"photo","media":"p1","x":0.36,"y":0.26,"w":0.52,"rotation":-4,"z":1,"frame":"tape"},
{"id":"i2","type":"photo","media":"p2","x":0.72,"y":0.48,"w":0.4,"rotation":8,"z":2,"frame":"polaroid"},
{"id":"i3","type":"text","text":"Miso is still holding your chair. She wants rent.","font":"handwritten","x":0.36,"y":0.58,"w":0.56,"rotation":-3,"z":3},
{"id":"i4","type":"text","text":"Thursday 2am ramen, table for one (tragic)","font":"marker","x":0.62,"y":0.74,"w":0.6,"rotation":3,"z":4},
{"id":"i5","type":"question","text":"Is Seattle 7-Eleven ramen better or are you lying to me?","font":"handwritten","x":0.5,"y":0.89,"w":0.8,"rotation":-1,"z":5},
{"id":"i6","type":"sticker","asset":"paw","x":0.12,"y":0.12,"w":0.15,"rotation":-12,"z":6},
{"id":"i7","type":"sticker","asset":"coffee","x":0.9,"y":0.28,"w":0.13,"rotation":14,"z":7}]}

EXAMPLE 3
Input: From Alex, to Mom. Occasion: Just because. Mood: Cozy. Notes: "first snow here today". Media: p1 (photo: snowy window).
Output (thin notes → fewer words):
{"background":"night_sky","template":"single_hero","items":[
{"id":"i1","type":"photo","media":"p1","x":0.5,"y":0.32,"w":0.78,"rotation":-2,"z":1,"frame":"plain"},
{"id":"i2","type":"text","text":"First snow here today. Thought of you.","font":"handwritten","x":0.5,"y":0.66,"w":0.8,"rotation":0,"z":2},
{"id":"i3","type":"sticker","asset":"moon","x":0.86,"y":0.1,"w":0.14,"rotation":10,"z":3}]}
"""

private let capsuleLayoutSchema: [String: Any] = [
    "type": "OBJECT",
    "properties": [
        "background": ["type": "STRING"],
        "template": ["type": "STRING"],
        "items": [
            "type": "ARRAY",
            "items": [
                "type": "OBJECT",
                "properties": [
                    "id": ["type": "STRING"],
                    "type": ["type": "STRING", "enum": LayoutItemType.allCases.map(\.rawValue)],
                    "media": ["type": "STRING"],
                    "text": ["type": "STRING"],
                    "font": ["type": "STRING"],
                    "asset": ["type": "STRING"],
                    "frame": ["type": "STRING"],
                    "title": ["type": "STRING"],
                    "artist": ["type": "STRING"],
                    "lines": ["type": "ARRAY", "items": ["type": "STRING"]],
                    // Without min/max the model happily returns pixels
                    // (x: 120) instead of page fractions.
                    "x": ["type": "NUMBER", "minimum": 0, "maximum": 1],
                    "y": ["type": "NUMBER", "minimum": 0, "maximum": 1],
                    "w": ["type": "NUMBER", "minimum": 0.05, "maximum": 1],
                    "rotation": ["type": "NUMBER"],
                    "z": ["type": "INTEGER"],
                ],
                "required": ["id", "type", "x", "y", "w"],
            ],
        ],
    ],
    "required": ["background", "template", "items"],
]

private let singleItemSchema: [String: Any] = [
    "type": "OBJECT",
    "properties": [
        "text": ["type": "STRING"],
        "title": ["type": "STRING"],
        "artist": ["type": "STRING"],
    ],
]
