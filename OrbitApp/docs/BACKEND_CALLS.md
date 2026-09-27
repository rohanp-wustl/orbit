# Backend calls

There's no functions layer in the free-tier MVP — no Firebase Cloud Functions, no
Supabase Edge Functions. The app talks directly to two things:

| What | How | Where in the code |
|---|---|---|
| Data (crew links, capsules, media rows) | Supabase's Postgrest client, straight from the app | `Shared/Services/CapsuleRepository.swift` |
| "Deliver this" / status changes | A live Postgres subscription (Supabase Realtime), not a push notification | `CapsuleRepository.subscribeToCapsules(...)` |
| The AI layout call | A direct HTTPS call to Gemini, straight from the app | `Shared/Services/GroundControlService.swift` |
| Uploading photos/video/voice notes | Supabase Storage client, straight from the app | not yet written — Phase "skeleton," see docs/ROADMAP.md |

## Calling these from SwiftUI

```swift
// Fetch once
let capsules = try await CapsuleRepository.shared.fetchCapsules(involvingUserId: myId)

// Live updates — call once per screen appearance, keep the returned channel
// alive for as long as the view is on screen
let channel = CapsuleRepository.shared.subscribeToCapsules(involvingUserId: myId) { capsules in
    // update @State / @Published here
}
// ...later, in onDisappear or deinit:
Task { await channel.unsubscribe() }
```

```swift
let request = GenerateLayoutRequest(crewNotes: notes, media: mediaContexts, assetCatalog: catalog)
let (layout, usedFallback) = await GroundControlService.generateLayout(for: request)
```

## Why this is simpler than the original plan, not just cheaper

The original Cloud-Functions design existed partly to keep the Anthropic key off the
client and partly because Firestore's query model made some of this awkward (its
lack of a real `OR` query is why the old `CapsuleRepository` ran two listeners and
merged them by hand). Postgres has neither problem: an `.or()` filter is one query,
and a public anon key plus Row Level Security is the intended access-control model,
not a workaround. Fewer moving parts, not a lesser version of the original plan.

## When to bring a functions layer back

Once this is headed anywhere past a hackathon demo, move the Gemini call server-side
so the key stops being public — a Supabase Edge Function is the natural home (unlike
Firebase's, it doesn't require a linked billing account to make outbound calls). The
retry/validate/fallback logic in `GroundControlService.swift` ports over almost
unchanged; only the networking wrapper around it needs to move.
