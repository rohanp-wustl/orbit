# Submission page (draft)

Checklist from the brief — each heading below maps to one item.

## Title
**Orbit: send a piece of your world**

## Problem and audience
People living far from the ones they love (college students, young professionals, scattered
friends) and the often less tech-savvy people on the other end (parents, grandparents). Staying
close means choosing between too little effort (a text, a photo in a group chat) and too much
effort (a physical care package or handmade scrapbook). Most AI answers generate content for you,
which strips out exactly what makes a care package meaningful: that it's yours.

## Solution
Orbit lets you send a **capsule**, a scrapbook-style digital care package, to someone in your
**crew**. Add your own photos, video, voice notes, and a few lines; **Ground Control** (our AI)
arranges them into a page with hand-made stickers and drafts a few short lines *in your voice*, in
about ten seconds. Every line is an editable card: keep it, edit it, redo it, or delete it. Then
launch: your package loads into a rocket, travels between your planets for as long as you choose,
lands on their launchpad with a notification, and unboxes piece by piece. Opened capsules become
pages in a scrapbook; one tap sends one back.

**The key design choice:** Ground Control never generates images. It returns a layout (JSON) that
places your real media and our hand-drawn assets, and it only writes what your notes support.
"Fly Me to the Moon": literally (rockets between planets), conceptually (AI that assembles rather
than generates), and emotionally (closing the distance to someone you miss).

## Photon track (Agents in iMessage)
Ground Control joins iMessage via Photon Spectrum: invite crew by phone, capsules land as texts
(page image, voice notes, question), replies launch back as capsules, polls when ambiguous, read
receipts mark capsules opened. See docs/PHOTON.md.

## Technology list
- **App:** Swift, SwiftUI (iOS 26+), Xcode; PhotosUI, AVFoundation/AVKit (voice notes, video),
  Apple Speech `SpeechAnalyzer` (on-device transcription), UserNotifications (local rich
  notifications), SwiftUI Canvas/TimelineView animations, `sensoryFeedback` haptics, AVAudioEngine
  (synthesized sound effects)
- **AI:** Google Gemini API (`gemini-3.8-flash`, fallback `gemini-3.7-flash`,
  `gemini-3.5-flash-lite`) with schema-forced JSON output
- **Backend:** Supabase (Postgres + Row Level Security, Realtime, Storage, anonymous Auth, Edge
  Functions/Deno for the Gemini proxy); `supabase-swift`
- **iMessage agent:** Photon Spectrum (`spectrum-ts`, cloud iMessage provider), Bun, `@supabase/supabase-js`
- **Design:** team asset library (rocket, planets, Cosmo mascot, launchpad, confetti, stickers)

## Screenshots
_Add: sign-in, Home launchpad, Create, Ground Control drafts cards, launch/travel, landing
notification, unboxing reveal, Galaxy, scrapbook._

## Demo / repository
_Repo link · backup video link · (live demo on 3 phones)_

## Build story
_See docs/BUILD_LOG.md. Summarize: what we built in the window (full send → travel → land → unbox
loop on real phones; Ground Control with an 8-case test set; voice, video, scrapbook, replies),
challenges (retired model id; 503 overloads; a privacy bug the test set caught; no paid Apple
account, so no push/widget: solved with Realtime + local notifications), lessons, what's next._

## Credits
_See docs/CREDITS.md. Include AI coding assistants used._

## Backup demo video
_Link._
