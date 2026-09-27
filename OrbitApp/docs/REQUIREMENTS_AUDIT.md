# Requirements audit (2026-09-26)

Every requirement from the organizer brief, the team to-do list, the build roadmap, the style
sheet, and the problem/solution + tech-stack deliverables, checked against the app.

**Key:** ✅ built · 🟡 partial / substituted (reason given) · 📄 written doc · 👤 needs a person · ⏭ decided against for MVP

## Team to-do list

| Requirement | Status | Where / notes |
|---|---|---|
| Shared code base: repo, README, .gitignore, .env template, no keys committed | ✅ / 👤 | `README.md`, `.gitignore`, `.env.example`, `Secrets.swift.example`; keys moved to gitignored `Secrets.swift`. **You:** create the GitHub repo (`docs/TEAM.md`) |
| Branches + owners | 📄 | `docs/TEAM.md` |
| AI suggestions as editable cards, not chat | ✅ | "Ground Control's drafts" cards (Edit / Redo / Remove), `LaunchFlowView` |
| How much the user writes vs the AI | 📄 ✅ | User writes facts; AI phrases ≤14-word captions / ≤70-word letter; thin notes → fewer words (`AI_SPEC.md` §2) |
| No generic AI visuals (sparkles, AI gradients) | ✅ | Sparkle icons removed from 4 places; Ground Control shown as Cosmo, never as "AI" |
| Which model, inputs (notes, occasion, mood), outputs (schema per item type), API failure/slowness | ✅ | Gemini 3.8 → 3.7 → 3.5-lite; occasion + mood chips on Create; per-type schema; repair → retry → salvage → fallback; 28 s budget; skip at 12 s |
| Voice & tone rules, ban list incl. "I hope this finds you well," "cherish," "journey" | ✅ | In the prompt **and** enforced in code (24 phrases) |
| 2–3 hand-written example capsules in the prompt | ✅ | 3 examples (Grandma/recipe, roommate/funny, thin notes) |
| Item types (letter, recipe card, playlist, question, photo…), limits, which the AI can generate | ✅ | 9 types with limits: photo, video, voice note, caption, letter, question, song, recipe, sticker. "Playlist" = up to 2 song cards linking to Apple Music (no uploaded audio) |
| Edit / regenerate / remove one item without redoing the capsule | ✅ | `ItemEditorSheet`, `GroundControlService.regenerate`, remove on card or canvas |
| Photon | ✅ code / 👤 setup | Ground Control in iMessage via Spectrum (`agent/`, `docs/PHOTON.md`): invite by phone, capsules land in iMessage, text replies fly back as capsules, polls, read receipts. **You:** Photon signup + allowlist + run the agent |
| Scrapbook: does an opened capsule become a page? Archive looks like a scrapbook? | ✅ | Yes to both: `ScrapbookView` (taped kraft-paper pages), card on Home |
| Planets/solar system: crew → planets, what distance means, how capsules travel and land, data model | ✅ 📄 | Crew = planets (stable hue); distance = recency of contact; rocket flies your planet → theirs for the chosen time; `docs/INFRASTRUCTURE.md` |
| **Packages sent as rockets** | ✅ | Package loads into a rocket in its color → countdown → liftoff → travel view → recipient sees the ship land and drop the package |
| Launch + unboxing animation, **sound**, haptics | ✅ | Animations + haptics throughout; synthesized sounds (beep, clunk, rumble, thud, pop, chime), toggle in Settings |
| Recipient opening without the app | ✅ | Via iMessage: Ground Control texts the page, voice notes and question; replies come back as capsules (Photon Spectrum) |
| Privacy: what's stored, who sees it, what the AI never includes | ✅ 📄 | `docs/PRIVACY.md`; in-app "What Ground Control sees"; `STAGE4_MIGRATION.sql` locks media to sender + recipient; phone/email rejected in code |
| Test set: 5–10 crew members/occasions | ✅ 📄 | 8 cases, run live 3×, results + fixes in `docs/AI_TEST_SET.md` |
| Finalize branding: name, logo, colors, type | ✅ / 🟡 | Name Orbit; **app icon made**; colors per style sheet; fonts still system fallbacks until Baloo 2 / Poppins / Caveat files are added. **You:** select AppIcon in target settings (1 click) |
| Mockups of key screens | ✅ | Provided by design; implemented |
| MVP loop: pick crew → build → send → deliver → open | ✅ | Tested on 2 devices in Stage 2/3 |
| Seed demo data incl. Grandma | ✅ | Offline demo mode (Settings → About) + live seeding steps in `docs/DEMO_GUIDE.md` |
| Test on real phones, small screens | 👤 | All screens scroll; needs a pass on your smallest phone |
| Build log | 📄 | `docs/BUILD_LOG.md` |
| Credits | 📄 | `docs/CREDITS.md` (assets were made with Recraft AI — disclose) |
| Video script (20 s / 60–75 s / 15 s / 10 s) | 📄 | `docs/VIDEO_SCRIPT.md` |
| Record video + backup demo | 👤 | Shot list in the script; backup plan in `DEMO_GUIDE.md` |
| Submission page per checklist | 📄 | `docs/SUBMISSION.md` draft (needs screenshots, links, team contributions) |

## Open questions — resolved

| Question | Decision |
|---|---|
| Final name / brand | **Orbit**, style sheet v5 + v6 depth pass |
| Web app or native widget? | Native iOS app. Real WidgetKit widget deferred (needs paid account for App Groups); in-app Mission Status card + local rich notifications instead |
| LLM provider | Google Gemini (free tier), server-side via Supabase Edge Function |
| Default delivery time / can the sender choose? | Sender chooses: Warp 10 s (default, demo), Cruise 1 min, Scenic 1 h, Overnight 8 am |
| Can recipients reply? | Yes: "Send one back" after unboxing and on any opened capsule |

## Build roadmap + tech stack documents

| Requirement | Status | Notes |
|---|---|---|
| AI never generates images; returns layout JSON; editor edits the same JSON | ✅ | |
| Photos → ~512 px thumbnails; one frame per video | ✅ | `MediaRepository.prepare`, `VideoFrames.poster` |
| On-device voice transcription (Speech) | ✅ | `SpeechAnalyzer` / `SpeechTranscriber` |
| 4–6 templates to choose from and adjust | ✅ | 4 templates with real slot positions, given to the AI and used by the fallback |
| Validate, retry once, fall back; "packing" animation | ✅ | + repair and salvage steps |
| Editor: drag / pinch / rotate, frame, font, caption, layer order, delete, redo item, asset tray, blank page, undo | ✅ | Blank page = "build it myself" |
| Voice notes recorded in-app, shown as a playable cassette | ✅ | `VoiceRecorderSheet`, `CassetteView` |
| Video plays in place (AVKit) | ✅ | `VideoClipView` |
| Music as suggestions/links, never uploaded | ✅ | Song cards → Apple Music search |
| Drawings (PencilKit) | ⏭ | Stretch goal |
| API key lives only on the server | ✅ | `ground-control` Edge Function deployed; key stored as a Supabase secret; app has no key |
| Rich notification when a capsule lands | 🟡 | Local notification with photo preview (no paid account needed). Remote push needs the $99 account |
| Home + lock-screen widgets, widget push | 🟡 | Needs paid account (App Groups). In-app Mission Status card substitutes |
| Crew links via invite code (or QR) | ✅ | Invite code + Share sheet; QR ⏭ |
| Real-time updates as safety net | ✅ | Supabase Realtime + pull to refresh |
| 3-phone demo, pre-seeded crews, delays in seconds | ✅ 📄 | Warp speed; `DEMO_GUIDE.md` |
| Group capsules (stretch) | ⏭ | "What's next" |
| Reply capsules (stretch) | ✅ | |
| Sign in with Apple | 🟡 | Needs paid account; anonymous name sign-in instead |
| Lottie animations | 🟡 | Replaced by native SwiftUI animations (no extra dependency) |
| Received capsules saved in an archive | ✅ | Scrapbook |

## Style sheet

| Requirement | Status |
|---|---|
| Palette, 6 recolor hues, 4 tabs in a floating pill nav, Settings as the one light screen | ✅ |
| Ships: two-tone nose (fixed), recolorable two-tone body, cloudGray fins, sky window, collar, nested flame | ✅ `RocketView` (drawn to spec, hue per capsule) |
| Home: gantry tower + platform, docked ship, waiting packages, "Send a package" CTA | ✅ |
| Create: recipient row, swatches, 2×2 tiles (Photo/Voice/Video/Note), Launch | ✅ (+ occasion, mood, speed) |
| Galaxy: home planet, crew planets at varying distance, dashed orbits, ship with trail dots | ✅ |
| Package opening: focus → shake → burst → reveal sheet → close or **swipe down** | ✅ |
| Cosmo poses wave / pack / sleep / cheer | 🟡 One wave artwork; poses done via motion + props until Design draws the rest |
| Flat/matte, no gradients | 🟡 Deliberately overridden by the team's v6 depth request (noted in `STYLE_SHEET.md`) |
| Fonts Baloo 2 / Poppins | 🟡 Rounded system fallbacks until font files are added |

## Judging criteria — how we answer them

| Criterion | Our evidence |
|---|---|
| Impact & relevance | Closes the effort gap for long-distance relationships; recipient flow built for less tech-savvy users (notification → tap → unbox) |
| Technical execution | Full loop on real phones; Realtime; schema-forced AI with repair/retry/salvage; test set with measured results; privacy enforced in SQL + code |
| Innovation & creativity | AI that arranges and never generates; rockets that carry packages between planets; orbit distance = how recently you've talked |
| UX & presentation | Mockup-faithful UI, sound + haptics, video script, demo guide with fallbacks |
