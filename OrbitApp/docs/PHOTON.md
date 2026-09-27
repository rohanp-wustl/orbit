# Photon — Ground Control in iMessage

Photon's bonus track (**Agents in iMessage**) runs alongside the main prompt: the same
project can win both. Qualifying requirement: integrate **Spectrum**, Photon's open-source
agent framework. Our integration is the `agent/` server (see `agent/README.md` to run it).

## The idea

Orbit's hardest user is the recipient who'll never install an app: a grandparent, a parent.
Our requirements audit had "can someone open a capsule without the app?" as **no**. With
Spectrum, **Ground Control joins their iMessage** as a participant in the relationship, not a
bot you query:

1. **Invite by iMessage** (Galaxy): name + number → Ground Control texts a welcome. They become
   a planet in the sender's galaxy with a 💬 badge.
2. **Capsules land in their texts**: a short context-aware line (grounded only in what's on the
   page), the scrapbook page as an image (rendered by the sender's app at launch), voice notes
   as native iMessage voice notes, and the sender's question.
3. **They reply by texting**: words, photos, videos, voice notes are gathered and launched back
   as a real capsule. It flies to the sender's app as a rocket and gets unboxed there. Their
   words stay verbatim; Ground Control arranges, it doesn't rewrite a person's reply.
4. **Human in the loop**: an ambiguous reply → iMessage poll "Who should I send this to?". The
   agent never guesses who a message is for.
5. **Context across time and channels**: the same capsule thread moves app → iMessage → app. The
   agent routes replies from the capsule history, and read receipts in iMessage become "Opened
   by Grandma" in the app. App users can also opt in to texts (Settings → Notifications).

## How it maps to Photon's judging

| Criterion | Orbit |
|---|---|
| **Vision** (hybrid intelligence) | The AI arranges and carries; humans write. It participates in a two-person relationship across an app and iMessage |
| **Craft** | One capsule, two native surfaces: the iMessage side uses voice notes, polls, read receipts, typing indicators |
| **Depth** (real context, edge cases) | Reply routing from history; polls when ambiguous; unknown numbers get a polite explanation; allowlist failures surface in the app with the fix; failed sends back off and retry; non-media files are declined kindly |
| **Traction** | Grandma needs nothing but iMessage. Runs today on real phones |

## Architecture

```
iOS app ──writes──▶ Supabase (capsules, imessage_invites, profiles.phone)
                        ▲   │ polled every 4 s with the service-role key
                        │   ▼
                 agent/ (Bun + spectrum-ts) ◀──▶ Photon iMessage line ◀──▶ Grandma's Messages
```

- Spectrum's cloud iMessage transport needs Node/Bun (gRPC), so the agent is a small
  long-running process, not a Supabase Edge Function.
- Data: `docs/STAGE5_MIGRATION.sql` adds `profiles.phone / imessage_only / imessage_updates`,
  `capsules.source / imessage_notified_at`, and the `imessage_invites` table.
- Spectrum APIs used: `Spectrum()`, `imessage.config()`, `im.user()`, `im.space.create()`,
  `space.send()` with `attachment()`, `voice()`, `poll()`, `space.responding()` (typing),
  inbound `text` / `attachment` / `voice` / `poll_option` / `reaction` / `read`.

## Setup checklist

- [ ] Photon account + promo `HACKWITHPHOTON`; project; connect iMessage
- [ ] Add every demo recipient's number under the project's **Users** (Pro allowlist)
- [ ] Run `docs/STAGE5_MIGRATION.sql`
- [ ] `agent/.env`: Spectrum project ID + secret, Supabase service-role key (+ optional Gemini key)
- [ ] Install Bun, `bun install`, `bun start`
- [ ] Test: invite a second phone by iMessage → send a capsule → reply by text → it lands in the app

## Known limits

Free/Pro shared lines are DM-only (no group chats), 50 new conversations per line per day, and
recipients must be allowlisted. The agent must be running for invites and iMessage deliveries.
App-to-app capsules still work without it.
