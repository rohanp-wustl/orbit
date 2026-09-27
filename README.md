# Orbit

**Send a piece of your world.** An iPhone app for sending scrapbook-style digital care packages
(**capsules**) to the people you miss (your **crew**). Add your own photos, video, voice notes, and
a few lines; **Ground Control**, our AI, arranges them into a page and drafts a few short lines in
your voice. Then launch: your package rides a rocket to their planet and lands on their launchpad
to be unboxed.

Ground Control never generates images. It returns a layout (JSON) that places your real media and
our hand-made assets, and every line it writes is an editable card.

## Run it

1. Open `orbit.xcodeproj` in Xcode (iOS 26+ device).
2. `cp OrbitApp/Shared/Services/Secrets.swift.example OrbitApp/Shared/Services/Secrets.swift` and fill it in.
3. Set up Supabase once: `OrbitApp/docs/SERVER_SETUP.md`.
4. Select your iPhone → Run.

No network? Settings → About → **Offline demo mode** (seeded crew incl. Grandma).

## Stack

SwiftUI · Supabase (Postgres + RLS, Realtime, Storage, anonymous Auth, Edge Functions) · Google
Gemini (schema-forced JSON) · Apple Speech (on-device transcription) · AVFoundation/AVKit ·
UserNotifications.

## Docs (`OrbitApp/docs/`)

| Start here | |
|---|---|
| `PIPELINE_STATUS.md` | Where we are + next steps |
| `REQUIREMENTS_AUDIT.md` | Every requirement vs. the app |
| `AI_SPEC.md` / `AI_TEST_SET.md` | Ground Control spec + test results |
| `INFRASTRUCTURE.md` | Planets, distance, travel, data model |
| `PRIVACY.md` · `SERVER_SETUP.md` · `TEAM.md` | Privacy, backend setup, branches/owners |
| `DEMO_GUIDE.md` · `VIDEO_SCRIPT.md` · `SUBMISSION.md` | Demo, video, submission |
| `BUILD_LOG.md` · `CREDITS.md` · `STYLE_SHEET.md` | Build story, credits, design system |

## Repo layout

```
OrbitApp/OrbitApp/        App: views, components, assets
OrbitApp/Shared/          Models, services (Supabase, Ground Control, media), theme
OrbitApp/docs/            Specs, SQL migrations, deliverables
supabase/functions/       ground-control Edge Function (Gemini key server-side)
```

Secrets live in gitignored `Secrets.swift` / `.env`. Never commit keys.
