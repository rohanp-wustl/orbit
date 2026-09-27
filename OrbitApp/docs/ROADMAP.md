# Roadmap

Four roles: **App lead**, **Backend and AI** (Supabase + Gemini), **Delivery and sync**
(Realtime, the in-app widget, auth), **Design and story**. Hours are wall-clock,
cumulative from hour 0 of the actual hackathon clock — everything in Stage 0 below
already happened before that clock starts.

---

## Stage 0 — Pre-production (already done, mostly)

Not part of the 48-hour clock — this is the design-system and architecture work that
makes the real clock faster instead of spent arguing about color hex or which backend
to use at midnight.

- [x] Style sheet locked (`docs/STYLE_SHEET.md`), theme tokens in code (`Shared/Theme/OrbitTheme.swift`)
- [x] Data models (`Shared/Models/`), matched to a real runnable schema (`docs/SUPABASE_SETUP.sql`)
- [x] AI contract — prompt, schema, validation, fallback (`docs/AI_CONTRACT.md`, `Shared/Services/GroundControlService.swift`)
- [x] Backend architecture chosen and written against (Supabase + Gemini, this rewrite)
- [ ] **HTML prototype visual polish** — `orbit_prototype.html` proved the interaction
      logic (navigation, color system, unboxing sequence) but isn't representative of
      final visual quality; it was always a wiring reference, not a design deliverable.
      Real craft happens in Stage 3-4's actual SwiftUI screens, which render with real
      fonts, real spring animations, and no browser-chrome compromises. Flagging this
      open rather than calling Stage 0 fully done.

**Stage 0 is NOT complete** until the box above is checked too.

## Stage 1 — Environment setup (needs you — not something I can do from here)

- [ ] Supabase project created, `docs/SUPABASE_SETUP.sql` run in its SQL editor
- [ ] Gemini API key from Google AI Studio, pasted into `GroundControlService.apiKey`
- [ ] Xcode project created, scaffold folders dropped in with correct target
      membership (App + Widget + NSE targets are **deferred** — see
      docs/PUSH_AND_WIDGET_PLAN.md — so for now it's just the App target)
- [ ] Supabase Swift package added (`https://github.com/supabase/supabase-swift`)
- [ ] `OrbitSupabase.projectURL` / `.anonKey` filled in from the Supabase dashboard
- [ ] A real iPhone signed into Xcode with a free Apple ID, building successfully
- **Done when:** the app builds and runs on a real device showing `OnboardingView`,
  and a manual test insert into the `capsules` table (via Supabase's dashboard) is
  fetchable from the app.

## Stage 2 — Skeleton: send and receive a bare capsule between two phones

- **App lead:** wire Supabase Auth's anonymous sign-in, build the media picker, wire
  `CapsuleRepository.createCapsule`.
- **Backend and AI:** confirm RLS policies actually allow the real query patterns the
  app uses (see docs/RISKS_AND_FALLBACKS.md), media upload → Supabase Storage.
- **Delivery and sync:** get `subscribeToCapsules` working end to end on two phones —
  this is the new pipe that used to be push, prove it early.
- **Design and story:** finalize the invite-code UI copy and the crew-home empty state.
- **Done when:** two physical phones, two accounts, one crew link, one capsule with a
  single hardcoded layout sent from phone A appears on phone B **without restarting
  the app** (i.e. the Realtime subscription actually fired).

## Stage 3 — Editor + Ground Control (parallel — both only depend on the `CapsuleLayout` schema, already fixed)

- **App lead + Design and story:** the canvas in `CapsuleEditorView` — drag, pinch,
  rotate gestures writing back to `LayoutItem.x/y/w/rotation`; undo via JSON snapshots.
- **Backend and AI:** wire `GroundControlService.generateLayout` to real uploads
  (thumbnail downscaling, optional on-device transcription via Speech framework).
- **Done when:** uploading 2-3 real photos plus a couple of sentences of notes returns
  a layout that opens correctly in the editor, on device — and killing the network
  mid-call still produces a usable fallback instead of a stuck loading screen.

## Stage 4 — Delivery moments

- **Delivery and sync:** `InAppWidgetPreviewView` reading live Realtime state,
  `LaunchView`/`UnboxingView` wired to real status transitions.
- **Design and story:** the launch/unboxing animations, the mascot.
- **Done when:** on phone A, editing and launching a capsule visibly updates phone B's
  in-app widget preview within a couple of seconds, and opening it plays the full
  unboxing sequence.

## Stage 5 — Polish and third phone

- **Everyone:** a third phone, three real accounts, pre-seeded crews — this is where
  two-phone assumptions quietly break.
- **Design and story:** consistency pass against `docs/STYLE_SHEET.md`.
- **Backend and AI:** tighten RLS now that real query patterns are known.
- **Done when:** three phones, three accounts, at least one capsule sent between each
  pair, no crashes, no visibly broken states.

## Stage 6 — Feature freeze, backup video, submission

- **Everyone:** stop building features. Fix only what's broken.
- **Delivery and sync:** pre-seed one capsule already "landed" so the live demo
  doesn't depend on live Gemini/Realtime timing in front of judges.
- **App lead:** record a full backup video of the demo flow.
- **Design and story:** submission blurb and screenshots.
- **Backend and AI:** confirm the Gemini key isn't committed anywhere it shouldn't be.
- **Done when:** the demo has been rehearsed twice, start to finish, on the actual
  devices you'll use for judging.
