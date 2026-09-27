# Ground Control — AI spec

The single most important design doc. Ground Control is Orbit's AI. Its job is **taste and
arrangement, not authorship**: the sender's photos, videos, voice notes, and notes are the
content; Ground Control picks a template and background, places every item, adds stickers, and
drafts a few short lines in the sender's voice from facts the sender gave it. Everything it
writes is a draft the sender can edit, redo, or remove — one item at a time.

Source of truth for the exact prompt, schema, validation, and fallback:
`Shared/Services/GroundControlService.swift`. This doc explains the decisions behind it.

---

## 1. What it is (and isn't)

| Ground Control **does** | Ground Control **never** |
|---|---|
| Choose a template (4) and background (4) from the team's asset library | Generate images, video, audio, or "AI art" |
| Place every media item the sender added | Invent media, or drop any the sender added |
| Draft ≤3 captions, ≤1 letter, ≤1 question, ≤2 songs — from the sender's notes | Invent facts, events, dates, places, or feelings |
| Transcribe a recipe the sender typed into a recipe card | Invent a recipe |
| Pick 2–4 stickers from the catalog | Reference an asset that isn't in the catalog |
| Match the requested occasion and mood | Mention AI, "Ground Control," or that anything was generated |

## 2. UI/UX — how suggestions appear

- **Editable cards, never a chat window.** After packing, the builder shows the capsule on the
  canvas *and* a strip of "Ground Control's drafts" cards (`LaunchFlowView.DraftCard`). Each card:
  **Edit** (sheet editor), **Redo** (rewrites only that item), **Remove**.
- **The sender writes the facts; Ground Control writes the phrasing.** The sender writes notes
  ("Grandma turns 81, her cookies come out flat when I make them"). Ground Control turns them into
  ≤14-word captions / a ≤70-word letter. Thin notes → Ground Control writes *less*, not generic filler.
- **Editing claims ownership.** Editing a draft clears its `aiDrafted` flag — it's the sender's
  words now and leaves the drafts strip.
- **No generic AI visuals.** No sparkle icons, no "AI-generated" badges or gradients, no robot
  imagery. Ground Control is represented by Cosmo (the mascot) packing a box and mission-control
  status lines — a character, not a technology. (Sparkle icons were removed from the app during
  the requirements audit.)
- **Build it myself.** "or build it myself" skips the AI entirely and opens the same editor on a
  plain template. AI-made and hand-made capsules are the same JSON.

## 3. AI integration

| | |
|---|---|
| Model | `gemini-3.8-flash` → `gemini-3.7-flash` → `gemini-3.5-flash-lite` (fallback chain on 429/500/503/timeout) |
| Output mode | `responseMimeType: application/json` + `responseSchema` (schema-forced) |
| Transport | Supabase Edge Function `ground-control` (key server-side) when `Secrets.useGroundControlFunction = true`; direct call otherwise (demo fallback) |
| Budget | 20 s per model attempt, 28 s total; loading screen offers "I'll arrange it myself" after 12 s |

### Inputs (what goes in)

- Sender + recipient first names, **occasion** (Just because, Miss you, Birthday, Congrats,
  Holiday, Get well, Thank you), **mood** (Sweet, Funny, Nostalgic, Hype, Cozy)
- Sender's notes (the *only* facts Ground Control may use)
- Photos → ~512 px JPEG thumbnails · Video → **one** still frame + length · Voice notes →
  on-device transcript (Apple Speech `SpeechAnalyzer`) + length — never the audio
- The asset catalog (names + mood descriptions) and each template's slot positions

### Outputs (what comes out) — the schema per item type

Every item: `id`, `type`, `x`, `y` (item **center**, 0–1 of a 3:4 page), `w` (width 0–1),
`rotation` (deg), `z`. Then per type:

| Type | Fields | Limit | Ground Control may write it? |
|---|---|---|---|
| `photo` | `media`, `frame` | 4 | Places only |
| `video` | `media` | 1 | Places only |
| `audio` (voice note) | `media` | 2 | Places only |
| `text` (caption) | `text` (≤14 words), `font` | 3 | Yes, from notes |
| `letter` | `text` (≤70 words), `font` | 1 | Yes, only if notes are specific enough |
| `question` | `text` (ends in "?") | 1 | Yes, grounded in notes — invites a reply capsule |
| `song` | `title`, `artist` | 2 | Only if notes mention music; real songs only; links out, never uploads |
| `recipe` | `title`, `lines[]` | 1 | Transcribe only — only if notes contain a recipe |
| `sticker` | `asset` | 5 | Yes, from the catalog |

## 4. Voice and tone rules

- First person, as the sender, talking to this one person — how they'd say it out loud.
- Use their specific details (names, places, foods, jokes, pets, numbers). Specific beats sweet.
- Short. A little funny or a little tender, matching the mood. Never greeting-card.
- Never invent anything. Thin notes → fewer, shorter words.
- No hashtags; at most one emoji per capsule; never mention AI.

### Ban list (checked case-insensitively; violations trigger a retry, then removal)

"I hope this finds you well", "cherish", "journey", "just wanted to say", "sending you love",
"sending love", "thinking of you today", "hope you're doing well", "missing you lots", "sending
hugs", "warm hugs", "treasure", "memories that last", "lifetime of memories", "near and far", "no
matter the distance", "distance means", "special someone", "embark", "heartfelt", "from the bottom
of my heart", "a testament to", "in this crazy world", "you mean the world".

## 5. Prompt examples (in the system prompt)

Three hand-written capsules show what "good" looks like (full JSON in `GroundControlService.swift`):

1. **Priya → Grandma Rose, Birthday, Sweet** — photo, voice note, recipe card transcribed from the
   notes, "Moon River" (mentioned in notes), caption "80 looks good on you, porch queen," question
   "What's the secret to the crust? Asking for me."
2. **Sam → Jordan, Miss you, Funny** — two photos, "Miso is still holding your chair. She wants
   rent.", "Thursday 2am ramen, table for one (tragic)", question about Seattle 7-Eleven ramen.
3. **Alex → Mom, Just because, Cozy, notes: "first snow here today"** — demonstrates *thin notes →
   one short caption*, no filler.

## 6. Privacy rules (in the prompt + enforced in code)

Never include addresses, phone numbers, emails, last names, passwords, financial or medical
details, or descriptions of strangers in photos. Code rejects any word item containing a phone
number or email pattern. See `docs/PRIVACY.md`.

## 7. Editing controls

- **Edit** any single item (captions, letters, questions, songs, recipes) — `ItemEditorSheet`.
- **Redo** any single word item — `GroundControlService.regenerate(_:in:for:)` rewrites only that
  item, keeps its position, avoids repeating the others, and must pass the same tone checks.
- **Remove** any single item (drafts strip or canvas delete).
- Canvas: drag / pinch / rotate, frame and font pickers, bring to front, add any item type or
  sticker, change background, undo (JSON snapshots).

## 8. Failure handling (validate → repair → retry once → salvage → fallback)

1. **Repair** cosmetic slips without a retry: drop empty items, add a missing "?", fix unknown
   fonts/frames, correct media type, place forgotten media into template slots, enforce limits.
2. **Validate** business rules (catalog membership, media ids, limits, tone, privacy).
3. **Retry once** with the exact problems listed.
4. **Salvage**: if only some word items still fail, remove just those.
5. **Fallback**: the first template's real slots filled with the sender's media plus a neutral
   "For Grandma Rose, from Priya" label. It deliberately does **not** paste the sender's notes
   (notes are written *about* the recipient and may contain private details — caught by the test set).

The editor never has to handle "the AI gave us garbage" as a UI state.

## 9. Test set

8 realistic crew members/occasions with results: `docs/AI_TEST_SET.md`. Rerun any time with
`await GroundControlTestSet.run()` (DEBUG).
