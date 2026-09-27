# Team, branches, and ownership

## Owners (split so people rarely edit the same files)

| Role | Owns | Main files |
|---|---|---|
| **Frontend / App lead** | Tabs, Create, editor, launch + unboxing screens | `OrbitApp/Views/*`, `Views/Components/*` |
| **AI** | Ground Control prompt, schema, validation, test set | `Shared/Services/GroundControlService.swift`, `GroundControlTestSet.swift`, `docs/AI_SPEC.md`, `docs/AI_TEST_SET.md` |
| **Backend / delivery** | Supabase schema + migrations, Realtime, Storage, Edge Function, notifications, Photon | `docs/*.sql`, `supabase/functions/*`, `Shared/Services/*Repository.swift`, `OrbitStore.swift`, `LandingNotifications.swift` |
| **Design / story** | Assets, style sheet, demo script, video, submission page | `Assets.xcassets`, `docs/STYLE_SHEET.md`, `docs/VIDEO_SCRIPT.md`, `docs/SUBMISSION.md` |

## Branches

- `main` — always builds and runs on a phone. Demo is cut from here.
- `feat/<area>-<thing>` — e.g. `feat/ai-regenerate`, `feat/photon-send`. One owner each.
- Merge to `main` via PR with one teammate's review; build on a phone before merging.
- **Freeze** (Stage 6): only `fix/…` branches merge.

## Getting a teammate running

1. Clone the repo; open `orbit.xcodeproj` in Xcode.
2. `cp OrbitApp/Shared/Services/Secrets.swift.example OrbitApp/Shared/Services/Secrets.swift` and
   fill it in (pinned in the team chat — never committed).
3. Target **orbit** → Signing & Capabilities → your team; select your iPhone; Run.

## Setting up the repo (one person, once)

```bash
cd ~/Documents/orbit
git init && git add . && git commit -m "Orbit: initial import"
gh repo create orbit --private --source . --push
```

Check `git status` before the first commit to confirm `Secrets.swift` is **not** listed.
