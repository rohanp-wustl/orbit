# Build log

Challenges, surprises, and lessons, in order. Feeds the "build story" section of the submission.
Add a line whenever something surprises you.

| When | What happened | What we did / learned |
|---|---|---|
| Setup | No budget for Firebase Blaze or a paid Apple Developer account | Switched to Supabase (free, no card) + Gemini free tier; delivery via Realtime instead of push |
| Setup | App ran but said "Add the Supabase Swift package first" | Package was downloaded but never linked to the target: `canImport` silently compiled Supabase out |
| Stage 2 | Every relaunch created a new anonymous account | Restore the saved session on launch |
| Stage 2 | Joining an invite code was impossible under RLS (can't read a row you're not in yet) | `join_crew(code)` security-definer RPC |
| Stage 2 | Realtime events never arrived | `postgresChange` must be registered *before* `subscribe()`; two racing Tasks broke it |
| Stage 2 | Capsules would have failed to load | Postgres returns microsecond timestamps the default ISO-8601 decoder rejects; custom decoder |
| Stage 3 | Every AI call silently fell back to the plain layout | `gemini-2.5-flash` had been retired (404). Lesson: log fallbacks loudly |
| Stage 3 | AI placed items in pixels, then by left edge | Schema min/max + "x/y are the item center" rule |
| Stage 4 | Rockets didn't feel like they *carried* anything | Recolorable ship in the package's hue with a cargo hatch; package loads in, flies the route, drops on landing |
| Audit | Test set: 503 "high demand" on most calls, one 46 s hang | Model fallback chain, per-attempt + total time budget, skip button |
| Audit | **Test set caught a privacy bug**: the fallback pasted raw notes (with a phone number) onto the page | Fallback never uses notes; code rejects phone/email patterns |
| Audit | Lite model's sloppy JSON rejected whole capsules | `repair()` + salvage single items instead of failing the capsule |
| Step 4 | Moved the Gemini key to a Supabase Edge Function; verified 401 for strangers, 200 for signed-in users | Key no longer ships in the app |
| Step 4 | Every call looked "busy" through the new server | Real cause: **429 free-tier daily quota** on the two main models, used up by our own test runs (~50 calls). Now logged as "out of free-tier quota". Lesson: quota is per model per day — don't burn it on demo day |
| Audit | Model flipped a nickname ("beta") in the Grandma case | Why every line is an editable/redoable card |

## Lessons

- Write the AI spec before the prompt; the ban list and "thin notes → fewer words" rule did more
  for quality than any model change.
- A test set pays for itself the first time you run it.
- Free-tier constraints forced better architecture (Realtime + local notifications work with the
  app closed or open, no push certificates).
