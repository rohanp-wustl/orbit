# Demo guide

## The live demo (3 phones)

| Phone | Signed in as | Role |
|---|---|---|
| A (presenter) | "Rohan" (or whoever presents) | Sender |
| B | "Grandma Rose" | The recipient the story is about |
| C | "Maya" | Shows the multi-person galaxy |

### Seed the crew (the night before — takes 5 minutes)

1. Install on all three phones from Xcode (free Apple ID; re-run if the 7-day profile expired).
2. Sign in on each with the names above.
3. Phone A → Galaxy → **Invite** → read the code → Phone B → Galaxy → **Join**. Repeat A ↔ C.
4. Send one Warp capsule B → A with a letter and a recipe card ("Sunday sauce"), and open it on A,
   so A's scrapbook already has a page and its galaxy shows Grandma's planet in the inner orbit.
5. Settings → Sound & haptics: sounds **on** (the landing thud and unboxing chime land well in a room).
6. Turn Notifications on for Orbit on every phone (iOS Settings → Orbit → Notifications).

### The run (~90 s, matches docs/VIDEO_SCRIPT.md)

1. **A: Create** → To: Grandma Rose · gold · Birthday · Sweet → add 2 photos + a 10 s voice note
   → Note: two specific lines → **Pack & launch**.
2. Cosmo packs (~5–10 s). Show the **drafts cards**: tap **Redo** on one caption to show it's
   one-item-at-a-time, edit another by hand.
3. **Launch** → package loads into the gold rocket → 3-2-1 → liftoff → travel view to Grandma's planet.
4. **B (Grandma)**: her Home shows the gold rocket on approach with an ETA → lands → package drops
   → "Open me". Tap: shake → burst → reveal card → voice note plays → **Send one back**.
5. **C**: open Galaxy to show planets at different distances and a ship in flight.

### Protect the AI quota

The Gemini free tier allows only a small number of calls per model per day. On demo day, don't
run the test set or practice more than a few times; do rehearsals the day before. If sponsor
credits are available, add billing to the Google AI Studio project.

### If something breaks

| Problem | Do this |
|---|---|
| Ground Control gives plain templates all day | Free quota is used up (Xcode console says "out of free-tier quota") → use "build it myself", or offline demo mode |
| Ground Control slow (> 12 s) | Tap "I'll arrange it myself"; keep talking over it — the template fallback still looks good |
| Wi-Fi dead | Settings → About → **Offline demo mode** on phone A: seeded crew (Grandma, Maya, Jordan), a landed gold package from Grandma, a violet rocket inbound — the whole send → launch → travel → unbox flow runs with no network |
| Realtime lag | Pull to refresh on Home |
| Anything else | Play the backup video |

## Backup recording

Record the full run on phone A and B with screen recording (Control Center) the night before;
stitch side by side. Keep it on a laptop and a phone.
