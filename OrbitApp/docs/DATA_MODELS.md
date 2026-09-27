# Data models

The actual runnable schema is `docs/SUPABASE_SETUP.sql` — paste it into Supabase's SQL
editor once the project exists. This doc is the plain-English map between that schema
and the Swift types in `Shared/Models/`, so both sides stay in sync as you build.

## Tables → Swift types

| Postgres table | Swift type | Notes |
|---|---|---|
| `profiles` | `AppUser` | One row per Supabase Auth user (`id = auth.uid()`), created via anonymous sign-in for the MVP — no email/password flow needed. |
| `crew_links` | `CrewLink` | Two fixed columns (`user_a`, `user_b`) instead of an array — simpler to query with `.or()` than Firestore's array-contains pattern. |
| `media_assets` | `MediaAsset` | The row is metadata only; the actual file lives in Supabase Storage at `storage_path`. |
| `capsules` | `Capsule` | `layout` is a `jsonb` column holding exactly the `CapsuleLayout` JSON shape — Ground Control's output and the editor's saved state are the same bytes, just like the original Firestore design. |

Column names are `snake_case`; Swift property names are `camelCase`.
`SupabaseConfig.swift` configures a `JSONEncoder`/`JSONDecoder` with
`convertToSnakeCase`/`convertFromSnakeCase` so no model needs hand-written
`CodingKeys` for this — the conversion happens once, centrally.

## Supabase Storage paths

```
uploads/{userId}/{mediaId}.{ext}          — original photo/video/audio
uploads/{userId}/{mediaId}_thumb.jpg       — downscaled thumbnail sent to Ground Control
previews/{capsuleId}.jpg                   — preview image shown in the opening reveal
```

## Why no `mediaAssets` array on `capsules`

A `LayoutItem.media` field is just an id string (e.g. `"media": "<uuid>"`), resolved
against `media_assets` by the app when rendering. This keeps Ground Control's JSON
output small and means it never has to embed full asset metadata — same reasoning as
the original Firestore design, just translated to a foreign key instead of a
subcollection.

## Realtime instead of push

There's no Cloud Function watching for row changes and firing a push notification —
see `docs/PUSH_AND_WIDGET_PLAN.md` for why (free Apple ID can't sign the Push
Notifications entitlement) and how `CapsuleRepository.subscribeToCapsules(...)`
replaces it with a live Postgres subscription instead.
