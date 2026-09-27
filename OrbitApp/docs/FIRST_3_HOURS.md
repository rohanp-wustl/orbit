# The first 3 hours (Stage 1: environment setup)

Do the 15-minute team sync **first**, before anyone splits off.

## 0:00–0:15 — Whole team

1. Open `Shared/Models/LayoutItem.swift` and read it out loud together — this is the
   one shape everyone's work depends on. Agree now if anything needs to change.
2. Create the Supabase project together (one person drives, share the screen) — the
   project URL and anon key go in a place everyone can see (a pinned message), since
   both App lead and Backend and AI need them.
3. Split into the four roles below.

## App lead — 0:15 to 3:00

1. Xcode → File → New → Project → iOS → App. Name it `OrbitApp`, interface: SwiftUI.
   **Don't add a Widget Extension or Notification Service Extension target** — both
   are deferred until there's a paid Apple Developer account (see
   `docs/PUSH_AND_WIDGET_PLAN.md`). Just the one App target for now.
2. Drag this scaffold's folders in with correct target membership — `OrbitApp/` and
   `Shared/` both go on the (single) App target.
3. Add the Supabase Swift package: File → Add Package Dependencies →
   `https://github.com/supabase/supabase-swift`.
4. Fill in `Shared/Services/SupabaseConfig.swift`'s `projectURL` and `anonKey` from
   Supabase's dashboard → Settings → API.
5. Sign into Xcode with your Apple ID (Xcode → Settings → Accounts) — this creates
   the free "Personal Team" automatically, no separate signup needed.
6. Build and run on a real device (Settings → Privacy & Security → Developer Mode may
   need enabling on the phone the first time). You should see `OnboardingView`.

## Backend and AI — 0:15 to 3:00

1. Go to supabase.com, sign up (no credit card prompt for the free tier), create a
   new project.
2. Dashboard → SQL Editor → paste in the entire contents of
   `docs/SUPABASE_SETUP.sql` → Run. Confirm all four tables show up under Table
   Editor.
3. Dashboard → Authentication → Providers → confirm "Anonymous Sign-ins" is enabled
   (it's on by default on new projects, but check).
4. Go to aistudio.google.com, sign in with a Google account, click "Get API key" →
   create one. No billing setup, no card.
5. Hand the Gemini key to whoever's editing `GroundControlService.swift` — paste it
   into the `apiKey` constant (yes, directly in the source for now; see
   `docs/BACKEND_CALLS.md` for why that's an acceptable trade for a demo and what to
   do before this goes anywhere past one).

## Delivery and sync — 0:15 to 3:00

1. Read `docs/PUSH_AND_WIDGET_PLAN.md` in full — this role's whole job changed from
   the original plan (no APNs, no WidgetKit target, no App Groups), so start there
   rather than assuming the old push-setup steps still apply.
2. Once the App lead has a running project, get `CapsuleRepository.subscribeToCapsules`
   compiling and confirm you can see Supabase's Realtime connection open in the
   dashboard's Logs → Realtime tab when the app runs.
3. Start on `InAppWidgetPreviewView` — it doesn't need any of the above to exist yet,
   it just needs a `Capsule?` to render, so it can be built and previewed in isolation.

## Design and story — 0:15 to 3:00

1. Name the 4-6 templates and the background/sticker asset list (names only for
   now) — this becomes the `assetCatalog` Backend and AI's `GroundControlService`
   call needs. Hand the list over by hour 3 even if the actual image files come later.
2. Sketch the unboxing sequence beat-by-beat, using `orbit_prototype.html` as the
   interaction reference (not the visual one — see Stage 0 in `docs/ROADMAP.md`).
3. Pick the display font and start exporting/sourcing it — font registration in Xcode
   needs the actual file.
