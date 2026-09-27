# Server setup (Supabase)

Everything server-side is Supabase (free tier, no card). Run these once per project.

## 1. Database — run in order (Dashboard → SQL Editor → New query → Run)

1. `docs/SUPABASE_SETUP.sql` — tables + row-level security + Realtime
2. `docs/STAGE2_MIGRATION.sql` — invite-code crew links (`join_crew`)
3. `docs/STAGE3_MIGRATION.sql` — private `media` Storage bucket
4. `docs/STAGE4_MIGRATION.sql` — media readable only by uploader + capsule recipient

Also: Authentication → Sign In / Providers → **Allow anonymous sign-ins** = on.

## 2. Ground Control Edge Function (keeps the Gemini key off the phone)

### Option A — in the browser (no installs)

1. Dashboard → **Edge Functions** → **Secrets** → add `GEMINI_API_KEY` = your key → Save.
2. Edge Functions → **Deploy a new function** → **Via Editor**.
3. Name it exactly `ground-control`, delete the sample code, paste all of
   `supabase/functions/ground-control/index.ts`, click **Deploy**.
4. Leave "Verify JWT" on (the app sends the signed-in user's token).

### Option B — command line

```bash
brew install supabase/tap/supabase          # once
cd ~/Documents/orbit
supabase login                               # opens the browser
supabase link --project-ref qfwjjveaigvppstrjwhw
supabase secrets set GEMINI_API_KEY=your-key-here
supabase functions deploy ground-control
```

Then in `OrbitApp/Shared/Services/Secrets.swift`:

```swift
static let geminiAPIKey = ""               // no longer needed in the app
static let useGroundControlFunction = true
```

The function (`supabase/functions/ground-control/index.ts`) rejects callers who aren't signed in,
only allows the three Ground Control models, and passes Gemini's status code through so the app's
overload → next-model fallback still works.

**Test it:** create a capsule with "Pack & launch". The Supabase Dashboard → Edge Functions →
ground-control → Logs should show a request.

## 2b. iMessage agent (Photon)

Run `docs/STAGE5_MIGRATION.sql`, then follow `agent/README.md` (Photon signup, allowlist
numbers under Users, `agent/.env`, `bun start`).

## 3. Each teammate's machine

```bash
cp OrbitApp/Shared/Services/Secrets.swift.example OrbitApp/Shared/Services/Secrets.swift
# fill in the Supabase URL + anon key (Dashboard → Project Settings → API)
```

`Secrets.swift` and `.env` are gitignored — never commit real keys.
