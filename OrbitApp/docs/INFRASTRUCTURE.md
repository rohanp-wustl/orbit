# Infrastructure: planets, distance, travel, delivery

How the space metaphor maps to real data. Everything below is implemented.

## The map

| Space thing | What it is in data | Where |
|---|---|---|
| **Your planet** (blue, center of Galaxy) | You (`profiles` row) | `GalaxyView` |
| **A crew member's planet** | A joined `crew_links` row; the other person's `profiles` row | `OrbitStore.crewMembers` |
| **Planet color** | Stable hue from the user's UUID bytes (same on every phone) | `OrbitHue.forUser` |
| **Orbit distance** | How recently you exchanged a capsule: <3 days → inner ring, <14 days → middle, else outer. Planets drift out when it's been a while | `GalaxyView.ring(for:)` |
| **A rocket** | A capsule row with status `launched`/`in_transit` | `capsules` table |
| **Rocket + package color** | `CapsuleLayout.packageColor` (sender picks on Create) | stored inside `layout` jsonb |
| **Flight time** | `delivery_delay_seconds`, chosen by the sender: Warp 10 s · Cruise 1 min · Scenic 1 h · Overnight (next 8 am) | `DeliverySpeed` |
| **Position along the route** | `(now − launched_at) / (delivery_at − launched_at)` | `LaunchView` travel scene, `GalaxyView` ships |
| **Landing** | `delivery_at` passes → recipient's phone sets status `landed` | `OrbitStore.markLandedWhenDue` |
| **Package on your launchpad** | Capsule to you with status `landed` | `HomeView.waitingPackages` |
| **Unboxing** | Status → `opened`, `opened_at` set, +30 XP | `PackageOpeningView` |
| **Scrapbook page** | Any opened capsule you received | `ScrapbookView` |

## A capsule's journey

1. **Create** — pick crew member, package color, occasion, mood, speed; add photos / video /
   voice notes / notes.
2. **Pack** — media uploads to Storage (`media/<sender uid>/<media id>.<jpg|m4a|mov>`);
   Ground Control returns layout JSON; sender edits.
3. **Launch** (sender's phone) — insert `capsules` row: `status=launched`, `launched_at=now`,
   `delivery_at=now+delay`. Animation: package loads into the ship's cargo hatch → 3-2-1 → liftoff
   → travel view (your planet → theirs) timed to the real delay.
4. **In transit** — Realtime pushes the new row to the recipient's phone in ~1 s. Their Home shows
   the capsule's ship on approach with an ETA; Galaxy shows the ship crossing between planets. A
   local "landed" notification is scheduled for `delivery_at` (fires even if the app is closed).
5. **Landing** (recipient's phone) — at `delivery_at` the recipient's app sets `status=landed`
   (only the recipient writes this, so phones never race). If they're watching, the ship descends,
   thuds down, pops its hatch, drops the package, and flies home.
6. **Open** — tap → focus → shake → burst → reveal card; `status=opened`; reward toast; the page
   joins their scrapbook; "Send one back" opens Create with the sender preselected.

## Status lifecycle

`draft → launched → (in_transit) → landed → opened`. `in_transit` is reserved (treated like
`launched`). Status updates flow to both phones through the Realtime subscription on `capsules`.

## Data model (Supabase Postgres)

See `docs/SUPABASE_SETUP.sql` + `STAGE2`–`STAGE4_MIGRATION.sql`. Tables: `profiles`, `crew_links`
(`user_b` null = open invite; `join_crew(code)` RPC claims it), `media_assets`, `capsules`
(`layout` jsonb holds the full page incl. `packageColor`). Swift models in `Shared/Models/`.

## Gamification (derived, no extra tables)

XP = 50/launch + 30/unboxing + 100/crew member; level every 250 XP; ranks Cadet → Legend;
6 achievements. `Shared/Models/PilotProgress.swift`.
