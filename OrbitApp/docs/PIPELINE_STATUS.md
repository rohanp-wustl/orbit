# Pipeline status

Updated 2026-09-26. Stages from `docs/ROADMAP.md`; full line-by-line check in
`docs/REQUIREMENTS_AUDIT.md`.

| Stage | Status |
|---|---|
| 0 · Pre-production (style sheet, models, AI contract, architecture) | ✅ Done |
| 1 · Environment (Supabase, Gemini, Xcode, phone signing) | ✅ Done |
| 2 · Skeleton: send + receive between two phones | ✅ Done — tested on 2 devices |
| 3 · Editor + Ground Control | ✅ Done — AI spec implemented, 8-case test set run (6/8 AI layouts, 2–11 s) |
| 4 · Delivery moments (launch, travel, landing, unboxing, notifications) | ✅ Code done — **needs a phone run-through** |
| 5 · Polish + third phone | 🟡 In progress — needs 3-phone run, small-screen pass, fonts, Photon |
| 6 · Freeze, video, submission | ⏳ Not started — script + submission draft written |

## What's built (since the last update)

- Rockets carry packages: recolorable ship per capsule, cargo-loading launch, travel view to the
  recipient's planet timed to the real delay, ship lands and drops the package on the recipient's side
- Ground Control per the AI spec: occasion/mood inputs, 9 item types with limits, ban list,
  3 prompt examples, privacy rules, editable drafts cards with per-item Redo, model fallback
  chain, repair/salvage, time budget, skip button
- Voice notes (record + on-device transcript + cassette playback) and video (poster frame to AI, inline playback)
- Sender-chosen delivery speed, "build it myself", reply capsules, scrapbook archive
- Local rich "capsule landed" notifications, synthesized sound effects, Cosmo poses
- Galaxy distance = recency of contact; gantry tower; app icon; offline demo mode with Grandma
- Keys moved to gitignored `Secrets.swift`; Gemini proxy Edge Function; media privacy migration
- Docs: AI spec, test set, infrastructure, privacy, server setup, demo guide, team/branches,
  video script, submission draft, build log, credits, Photon placeholder, requirements audit

## Next steps, in order

1. **Run the new SQL:** `docs/STAGE4_MIGRATION.sql` in the Supabase SQL editor.
2. **App icon:** target **orbit** → General → App Icons → select **AppIcon**.
3. **Phone run-through (2 phones):** Create with photo + voice note + video → drafts cards (Edit,
   Redo) → launch → watch it land on the other phone → unbox → Send one back. Try Scenic (1 h) once,
   close the app, and confirm the lock-screen notification. Report anything odd.
4. ✅ **Edge Function deployed** — app calls it; the Gemini key is no longer in the app
   (verified: strangers get 401, signed-in users get layouts).
5. **Create the GitHub repo** (`docs/TEAM.md`); confirm `Secrets.swift` isn't committed.
6. 🟡 **Photon:** code done (`agent/`, `docs/PHOTON.md`). **You:** Photon signup (promo `HACKWITHPHOTON`), connect iMessage, allowlist demo numbers under Users, run `docs/STAGE5_MIGRATION.sql`, fill `agent/.env`, install Bun, `bun start`.
7. **Stage 5:** third phone, smallest-screen pass, add font files, Design's missing Cosmo poses.
8. **Stage 6:** freeze, record video + backup (script ready), screenshots, finish `docs/SUBMISSION.md`.
