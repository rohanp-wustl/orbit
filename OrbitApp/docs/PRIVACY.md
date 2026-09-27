# Privacy

What Orbit stores, who can see it, and what Ground Control never does. The in-app version is
Settings → About → "What Ground Control sees."

## What's stored

| Data | Stored? | Where | Who can read it |
|---|---|---|---|
| Display name | Yes | `profiles` | Signed-in users (needed to show crew names) |
| Crew links | Yes | `crew_links` | Only the two people on the link |
| Capsule layout (captions, letter, positions) | Yes | `capsules.layout` | Only sender + recipient (RLS) |
| Photos / videos / voice notes | Yes | Storage `media/<sender uid>/…` | Uploader + recipient of a capsule that references the file (`STAGE4_MIGRATION.sql`) |
| Voice-note transcript | Yes | `media_assets.transcript` | Uploader (+ that capsule's recipient) |
| **Sender's notes to Ground Control** | **No** | Sent once to the model, then discarded | — |
| Account | Anonymous (no email, no password, no phone) | Supabase Auth | — |

## What goes to the AI

- Small (~512 px) photo thumbnails, one still frame per video — never full files
- Voice-note **transcripts** made on the phone — never the audio
- First names, occasion, mood, the sender's notes, the asset catalog
- Via the `ground-control` Edge Function (key server-side) once deployed; Google's API terms
  apply to what's sent. Free-tier inputs may be used by Google to improve products — say so in
  the submission and move to a paid tier before any real launch.

## What Ground Control never includes

Addresses, phone numbers, emails, last names, passwords, financial or medical details,
descriptions of strangers in photos, invented facts. Enforced in the prompt **and** in code
(phone/email patterns are rejected; see `GroundControlService.toneErrors`). The test set includes
a privacy-trap case (`docs/AI_TEST_SET.md` #8).

## Known gaps (be honest in the submission)

- Before running `STAGE4_MIGRATION.sql`, any signed-in user could read media by exact path.
- Direct-call mode (before the Edge Function is deployed) ships the Gemini key in the app binary.
- No account deletion UI yet; no content moderation; no blocking a crew member.
