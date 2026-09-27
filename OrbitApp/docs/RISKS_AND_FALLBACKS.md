# Risks and fallbacks

## Gemini's free-tier rate limit gets hit mid-demo

The free tier is generous for development but is still a real limit (roughly 15
requests/minute, ~1,500/day at the time this was written — confirm current numbers at
ai.google.dev, they move). Mitigation already built in: `GroundControlService`'s
retry is capped at one extra call, then falls back, so a rate-limit error never hangs
the UI. For the actual demo, pre-generate and cache the layout for whatever capsule
you plan to show live, rather than calling the API fresh in front of judges.

## Gemini/schema-forced output still comes back malformed

Same shape-then-content validation as before covers this (see docs/AI_CONTRACT.md) —
what's genuinely untested is the exact `responseSchema` field-name/casing
requirements, since this couldn't be run against a live network connection while
building it. Budget real time early to make one real call and confirm the shape
matches what `GroundControlService.swift` expects, rather than discovering a mismatch
during the demo.

## Supabase Realtime subscription drops or lags

Unlike push, this requires a live connection — if wifi is bad, the "recipient sees it
land" moment can lag or silently miss. Mitigation: on `CrewHomeView` appearance, do a
one-time `fetchCapsules` in addition to subscribing, so a missed realtime event
self-heals the next time the screen is opened, rather than requiring the connection
to have been perfect the whole time.

## Row Level Security policies lock out a query you didn't expect

`docs/SUPABASE_SETUP.sql`'s policies are deliberately permissive, but a mistyped
`auth.uid()` check can produce an empty result that looks like "no data" instead of
"blocked by RLS," which is a confusing failure mode to debug live. If a query returns
nothing unexpectedly, check the Supabase dashboard's API logs (they show the actual
Postgres error, including RLS denials) before assuming the data isn't there.

## Free Apple ID's 7-day provisioning expiry lands mid-hackathon

Personal Team provisioning profiles expire a week after creation. A 48-hour hackathon
won't hit this, but if there's a gap between setup and the actual build days, budget
five minutes to re-run from Xcode and refresh it.

## Running out of time on the editor

Unchanged from the original plan — this is still the single largest, most open-ended
piece of work. If it's clearly behind by the roadmap's midpoint:
- Cut gesture support down to drag-only (skip pinch-resize and rotate).
- Cut the asset tray's ability to *add new* items; keep editing of AI-placed items only.
- Do not cut undo — losing a placement with no way back is the kind of rough edge a
  judge notices in the first thirty seconds of trying the app themselves.

## What's genuinely unresolved past the demo

Same as before, still not this weekend's problem: content moderation, long-term media
retention/privacy, what happens when a `crew_link` needs to be removed (blocking, not
just deleting the row). Add: the Gemini key is currently embedded in the client —
fine for a demo, a real problem the moment this is shared outside the team (see
docs/BACKEND_CALLS.md's "when to bring a functions layer back").
