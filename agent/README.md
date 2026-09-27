# Orbit agent — Ground Control in iMessage

Orbit's entry for Photon's **Agents in iMessage** track, built on
[Spectrum](https://photon.codes/docs/spectrum-ts/introduction). Ground Control
joins your crew's iMessage threads so people who'll never install an app (hi,
Grandma) still get capsules — and can send one back just by texting.

| Moment | What happens |
|---|---|
| **Invite** | In Orbit → Galaxy → *Invite by iMessage*, enter a name + number. Ground Control texts them a welcome. They're now a planet in your galaxy (💬 badge). |
| **Landing** | When your rocket lands, Ground Control texts them a short context-aware line, the scrapbook page as an image, your voice notes as real iMessage voice notes, and your question. |
| **Reply** | Whatever they text back — words, photos, videos, a voice note — is gathered for 8 s and launched back as a real capsule. It flies to your app as a rocket. Their words are kept verbatim. |
| **Who's it for?** | If it's unclear who a reply is for, Ground Control asks with an iMessage poll. |
| **Opened** | Their iMessage read receipt marks the capsule "Opened by Grandma" in your app. |

Everything flows through Supabase (the app writes, the agent polls with the
service-role key), so this runs on a laptop with no public URL.

## Run it

1. **Photon:** sign up at [app.photon.codes](https://app.photon.codes/dashboard),
   apply promo code `HACKWITHPHOTON` (free month of Pro), create a project, and
   connect iMessage. Copy the project ID + secret from **Settings**.
2. **Allowlist (automatic):** Pro sends through a shared line that only texts
   numbers registered under your project's **Users** tab. This is Photon's
   anti-spam rule, separate from Orbit's sign-in. The agent registers each number
   itself before texting it (`src/photon.ts`). To enable that, run
   `npx @photon-ai/cli login` once and set `PHOTON_USER_EMAIL` in `.env`. Without
   it, add numbers in the dashboard by hand. If a send still fails with
   `Target not allowed for this project`, the app shows that hint on the invite.
   The Business plan (dedicated line) has no allowlist.

   **Opt-in:** a shared line also can't text someone until they've texted it
   once. When that happens the invite goes to *waiting*, and the app shows
   "Ask them to text hi to (628) 268‑8640" with a share button. Their first text
   triggers the welcome. It isn't launched as a capsule. Needs
   `OrbitApp/docs/STAGE5B_MIGRATION.sql`.
3. **Supabase:** run `OrbitApp/docs/STAGE5_MIGRATION.sql`. Copy the **service role**
   key (Project Settings → API). It bypasses row-level security — it lives only in
   `agent/.env`, never in the app or the repo.
4. **Install Bun** (once): `curl -fsSL https://bun.sh/install | bash`, then open a new terminal.
5. **Configure + start:**
   ```bash
   cd ~/Documents/orbit/agent
   cp .env.example .env      # fill in the values
   bun install
   bun start
   ```
   You should see `🛰️ Ground Control is online in iMessage.` Leave it running
   during the demo.

## Limits to know (Photon Free/Pro)

- DMs only — shared-pool lines can't create group chats (Business plan can).
- 50 new conversations per line per day; 5,000 messages per server per day.
- The sending number can differ per recipient (shared pool).

## Files

- `src/index.ts` — Spectrum app, polling loop (invites, landings), inbound handling (replies, polls, read receipts)
- `src/orbit.ts` — Supabase data layer (same tables/JSON as the iOS app)
- `src/groundControl.ts` — Ground Control's landing line (Gemini, same tone rules as the app)
