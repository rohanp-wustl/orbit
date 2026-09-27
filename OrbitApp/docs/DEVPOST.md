## Inspiration

Every one of us has someone we miss who's hard to stay close to: a grandparent back home, a sibling in another time zone, the friend we swore we'd call every week after graduation. Staying close over distance usually forces a choice between two bad options:

- **Too little effort:** a text, a photo dropped in the group chat. Easy, but disposable. Nobody revisits it.
- **Too much effort:** a real care package, a handmade scrapbook, a letter in the mail. Special, but it takes hours and money, so it rarely happens.

We wanted the middle ground: something with the warmth of a care package that a busy 20-year-old can put together on a Tuesday night in under ten minutes.

We also noticed that most "AI-powered" answers to this problem generate the content for you: AI captions, AI images, AI everything. That strips out the one thing that makes a care package mean something, which is that **it's yours**. So we set ourselves a rule from the first hour: **the AI never generates an image.** It only arranges the real photos, voice, and words you give it.

The hackathon theme, *Fly Me to the Moon*, fit perfectly. Sinatra's song is about longing for someone far away. Orbit turns that feeling into something literal: you pack a capsule, it launches on a rocket, flies across the space between your two planets, and lands on their launchpad.

## What it does

**Orbit** is an iPhone app for sending **capsules**, scrapbook-style digital care packages, to your **crew**, the people you care about.

1. **Pack.** Pick a crew member, a package color, an occasion, and a mood. Add your own photos, videos, voice notes, and a few lines about the moment.
2. **Ground Control arranges it.** Our AI, *Ground Control*, turns that into a scrapbook page in a few seconds. It picks a paper background and template, places your media, adds washi tape and stickers from our hand-made asset library, and drafts a few short captions **in your voice, using only details you provided**. Every line it writes is an editable card that you can edit, redo, or delete one at a time.
3. **Launch.** Your package loads into a rocket painted in its color: 3‑2‑1, liftoff. Flight time is up to you: **Warp** (10 s), **Cruise** (1 min), **Scenic** (1 h), or **Overnight** (lands at 8 am).
4. **Land and unbox.** The recipient sees the rocket on approach with a live ETA, gets a notification when it lands, and unboxes it: the package focuses, shakes, bursts open, and your page is revealed. It's saved to their scrapbook, and **"Send one back"** starts a reply with you preselected.
5. **Your galaxy.** You're the blue planet at the center, and each crew member is a planet in their own color. Planets drift to outer orbits when you haven't exchanged a capsule in a while, a gentle visual nudge to reach out. Rockets in flight cross between planets in real time.

### No app? No problem: Ground Control in iMessage (Photon)

The people we miss most, like grandparents and parents, are often the least likely to install a new app. So Ground Control also lives in **iMessage**, built on **Photon Spectrum**:

- **Invite by phone number.** Grandma becomes a planet in your galaxy (with a 💬 badge) and gets a friendly welcome text from Ground Control.
- **Landings arrive as texts.** When your rocket lands, Ground Control texts her a short, context-aware line, **your scrapbook page as an image**, your voice notes as **real iMessage voice notes**, and your question.
- **She replies by just texting.** Words, photos, videos, or a voice note are gathered for a few seconds and **launched back to you as a real capsule**, a rocket flying into your app. Her words are kept verbatim; Ground Control arranges them but never rewrites a person's reply.
- **Human in the loop.** If it's unclear who a reply is for, Ground Control asks with an **iMessage poll** instead of guessing.
- **Read receipts become "Opened by Grandma"** in your app.

## How we built it

**App:** Swift and SwiftUI (iOS 26), with an `@Observable` store, SwiftUI springs, `KeyframeAnimator`, haptics via `sensoryFeedback`, and custom-drawn rockets, planets, and packages that follow our matte style sheet: flat fills, one recolor hue per ship, no gradients. The media stack is `PhotosPicker`, AVFoundation for voice recording, AVKit for video, and Apple's **Speech** framework for on-device voice-note transcription, so Ground Control knows what a voice note says without the audio leaving the phone.

**Backend (Supabase):** Postgres with row-level security, **Realtime** for delivering capsules phone to phone in about a second, Storage for media, anonymous Auth, and an **Edge Function** that is the only place our Gemini API key lives.

**The AI contract.** Ground Control returns **layout JSON**, not pixels. The editor edits the exact same JSON, so an AI-made capsule and a hand-made one are the same data. Every position is a fraction of the page, so a layout looks identical on every screen size:

$$
x,\; y,\; w \in [0, 1], \qquad (x_{\text{px}},\, y_{\text{px}}) = (x \cdot W,\; y \cdot H)
$$

where $(x, y)$ is the item's **center** and $W \times H$ is the page size on that phone.

**The Ground Control pipeline:**

1. The phone shrinks each photo to a ~512 px thumbnail, grabs one frame per video, and transcribes voice notes on-device.
2. The Edge Function sends the thumbnails, transcripts, crew notes, occasion, mood, and a catalog of our asset names to **Google Gemini** with a **schema-forced JSON** response. The prompt carries hand-written example capsules, voice and tone rules, and a ban list of greeting-card phrases ("hope this finds you well," "cherish," "journey"…).
3. The app then runs **repair → validate → retry once → salvage → template fallback**. It checks that every media ID exists, every asset is in our catalog, numbers are in range, and no text contains banned phrases, phone numbers, or emails. If the model misbehaves, we keep the good items rather than throw out the whole capsule.
4. A model fallback chain (`gemini-3.8-flash` → `3.7-flash` → `3.5-flash-lite`) runs inside a strict time budget:

$$
t_{\text{attempt}} \le 20\,\text{s}, \qquad \sum_i t_i \le 28\,\text{s}
$$

with a "skip" button at 12 s so the sender is never stuck staring at a spinner.

**The space model, all real data:**

- A rocket's position along its route is its flight progress:

$$
p(t) = \operatorname{clamp}\!\left(\frac{t - t_{\text{launch}}}{t_{\text{delivery}} - t_{\text{launch}}},\; 0,\; 1\right)
$$

- A crew member's orbit ring comes from $\Delta$, the days since your last exchanged capsule:

$$
\text{ring}(\Delta) =
\begin{cases}
\text{inner}, & \Delta < 3 \\
\text{middle}, & 3 \le \Delta < 14 \\
\text{outer}, & \Delta \ge 14
\end{cases}
$$

- The rewarding, gamified feel comes from derived XP, with no extra tables:

$$
\text{XP} = 50\,n_{\text{launches}} + 30\,n_{\text{unboxings}} + 100\,n_{\text{crew}}, \qquad \text{level} = \left\lfloor \frac{\text{XP}}{250} \right\rfloor + 1
$$

**iMessage agent (Photon):** a Bun/TypeScript service using **`spectrum-ts`**. It watches Supabase with a service-role key, texts landings (the page is rendered on the sender's phone with `ImageRenderer` and uploaded as a preview), gathers inbound replies into capsules, asks via polls, and maps read receipts to "opened." Because it only talks to Supabase, it runs from a laptop with no public URL.

## Challenges we ran into

- **No budget for the planned stack.** Our research plan assumed Firebase Blaze and a paid Apple Developer account for push. We didn't have either, so we moved to **Supabase + Realtime + local notifications**. That turned out to be simpler: capsules arrive in about a second, and landings notify even with the app closed, with no push certificates needed.
- **Realtime events never arrived.** The listener has to be registered *before* subscribing, and two racing tasks were silently breaking it.
- **Invites were impossible under row-level security.** You can't read a crew row you're not in yet. We fixed it with a `join_crew(code)` security-definer RPC.
- **The model we started with was retired (404).** Every capsule silently fell back to a plain template. Lesson: log fallbacks loudly.
- **Model overload and quotas.** We hit 503 "high demand" errors, one call hung for 46 s, and our own test runs used up the **free-tier daily quota** (429). This is what drove the fallback chain, time budget, and skip button.
- **Our test set caught a privacy bug.** An early fallback pasted the sender's raw notes onto the page, including a phone number and an email. The fallback now never uses notes, and the validator rejects phone and email patterns in any line.
- **Photon's shared iMessage lines.** On the Pro plan, a shared line only texts numbers registered as users, and only after that person has texted their assigned number once. We automated registration from the agent, and built an opt-in flow: the app shows "Ask Grandma to text 'hi' to (628) 268‑8640," and her first text triggers the welcome instead of becoming a capsule.

## Accomplishments that we're proud of

- **The AI never makes a single pixel.** Every visual on a capsule is either the user's own media or an asset our team made. Ground Control's job is taste and arrangement, and it still produces pages that feel designed.
- **An AI test set with results we can show.** We wrote 8 realistic crew members and occasions (Grandma's birthday, a get-well-soon with inside jokes, a thin-notes "just because," a privacy trap). On the final run we got **6/8 full AI layouts, typically 2–11 s, with zero banned phrases, zero invented facts, and the privacy case clean**.
- **Words that sound like a person.** A real Ground Control line from testing: *"Found our 8th grade volcano poster. We still owe Mr. Patel an apology."*
- **It works end to end across real phones.** Pack → arrange → launch → fly → land → unbox → send one back, synced live between devices.
- **Grandma never installs anything.** She gets the page, the voice note, and the question in iMessage, texts back, and her reply flies into your app as a rocket.
- **Secrets stay off the phone.** The Gemini key lives only in the Edge Function (unauthenticated callers get a 401), and the service-role key lives only on the agent's server.

## What we learned

- **Write the AI spec before the prompt.** The ban list and the "thin notes → fewer words" rule improved quality more than any model change.
- **A test set pays for itself the first time you run it.** Ours found a privacy leak we would have demoed.
- **Design for failure.** Validation, salvage, and a graceful fallback matter more than the happy path, because live models get slow, overloaded, or retired mid-hackathon.
- **Editable cards beat chat.** In one test the model flipped who calls whom by a nickname. Making every line an editable, redoable card keeps the human in control.
- **Constraints forced better architecture.** Losing push pushed us to Realtime and local notifications, and losing "everyone has the app" pushed us to iMessage.
- **Meet people where they already are.** For older recipients, the best interface is the one already on their phone.

## What's next for [Photon] Orbit

- **A dedicated Ground Control number** (Photon Business line) so every crew member texts the same number, plus **group capsules** in iMessage group chats for family threads.
- **Memory across time:** Ground Control remembering past capsules ("last time you sent Grandma the cookie recipe…") so it can suggest callbacks, always as editable cards.
- **Gentle, opt-in nudges** when a planet drifts to the outer orbit ("It's been two weeks since you sent Dad something").
- **Rich push notifications and home/lock screen widgets** with a cover image once we have a paid developer account, plus TestFlight so friends and family can install it.
- **More ways to be yourself:** PencilKit drawings, song previews, and recipe cards from a photo of a handwritten recipe.
- **Accessibility** for older recipients: larger type, VoiceOver-first unboxing, and read-aloud captions.
