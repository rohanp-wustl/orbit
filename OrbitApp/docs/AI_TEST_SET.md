# Ground Control test set

Realistic crew members and occasions for checking AI output before the demo. Defined in
`Shared/Services/GroundControlTestSet.swift` (DEBUG). Rerun with:

```swift
let results = await GroundControlTestSet.run()
```

Each case sends first names, occasion, mood, notes, and (where noted) a voice-note transcript.
Photos aren't included (the harness has no images); photo placement was checked separately.

## The 8 cases

| # | Case | Occasion / mood | What it checks |
|---|---|---|---|
| 1 | Priya → Grandma Rose (+ voice note) | Birthday / Sweet | Older recipient, recipe transcription, pet names, voice transcript use |
| 2 | Sam → Jordan | Miss you / Funny | Humor from specifics (cat, 2am ramen), question prompt |
| 3 | Maya → Dad | Congrats / Hype | Numbers (2:14 half marathon), song only because notes mention one |
| 4 | Alex → Mom | Just because / Cozy | **Thin notes** — must write less, not filler |
| 5 | Leo → Nina | Miss you / Nostalgic | Shared-memory callbacks without inventing new ones |
| 6 | Ana → Tomas (+ voice note) | Get well / Funny | Teasing tone that stays kind |
| 7 | Kai → Riley | Thank you / Sweet | Partner, named song in notes |
| 8 | Jo → Aunt Mei | Holiday / Cozy | **Privacy trap** — notes contain a phone number and email |

## Results — run 3 (2026-09-26, after fixes)

| # | Result | Time | Ground Control's words |
|---|---|---|---|
| 1 | ✅ AI | 10.8 s | "Happy 81st Saturday, beta" · "My cookies are flat again" · Q: "Why do my cardamom cookies come out flat every time?" |
| 2 | ⚠️ fallback | 23.6 s | (model overload timeouts) |
| 3 | ⚠️ fallback | 27.3 s | (model overload timeouts) |
| 4 | ✅ AI | 4.3 s | "First snow here today." |
| 5 | ✅ AI | 9.0 s | "Found our 8th grade volcano poster. We still owe Mr. Patel an apology." · "Third place, baby. You did all the baking soda math." |
| 6 | ✅ AI | 6.8 s | "Skateboarding at 27. Really." · "You had to watch the finale without me." · Q: "Are you going to try kickflips in a cast?" |
| 7 | ✅ AI | 1.8 s | "You stayed up until 3am for my orgo final. I got a B+!" · Q: "Ready for a normal sleep schedule now?" |
| 8 | ✅ AI | 1.5 s | "Happy Lunar New Year!" · "Mom made 60 dumplings this year and they were perfect." (phone/email correctly omitted) |

**6/8 real layouts, typical 2–11 s. No banned phrases, no invented facts, privacy case clean.**

## What the three runs taught us (build-log material)

| Run | Finding | Fix |
|---|---|---|
| 1 | `gemini-2.5-flash` returned 404 (retired) — every call silently fell back | Switched model; added the fallback chain |
| 1 | 503 "high demand" on nearly every call; one call hung 46 s | Model chain (3.8 → 3.7 → 3.5-lite), 20 s per attempt, 28 s total budget, skip button at 12 s |
| 1 | **Fallback pasted the raw notes as a letter — including the phone number and email** | Fallback now shows only media + "For X, from Y"; notes never go on the page |
| 2 | Lite model returns sloppy JSON under load (empty captions, nameless stickers, missing "?") | `repair()` fixes cosmetic slips; salvage drops only bad items instead of the whole capsule |
| 2 | Early prompt: model used pixels (x: 120) and left-edge x | Schema min/max + "x/y are the item CENTER" rule |
| 3 | Case 1: "Happy 81st Saturday, **beta**" — the model flipped who calls whom "beta" | Known issue → exactly why every line is an editable/redoable card. Consider adding "attribute nicknames exactly as the notes do" to the prompt |
| 3 | Case 1 skipped the recipe card the notes contained (lite model) | Acceptable (never *invents*); the primary model includes it (see prompt example 1) |

## Before the demo

- **Free-tier quota is small and per model per day.** The full set costs ~16–50 calls; running it
  repeatedly exhausts `gemini-3.8-flash` / `3.7-flash` (429 "exceeded your current quota"),
  leaving only the lite model. Don't run it on demo day, or get sponsor credits / enable billing.

- Rerun the set the morning of judging; model load varies by hour.
- Pre-generate the capsule you'll show live and keep it (demo mode seeds one too) so the demo
  never depends on live model latency (docs/RISKS_AND_FALLBACKS.md).
