# Delivery: realtime instead of push, in-app instead of a widget

## The constraint this works around

A free Apple ID gets Xcode's "Personal Team" signing — real, on-device, at no cost —
but it can't sign the entitlements Push Notifications, App Groups, or Sign in with
Apple depend on. That's not a guess; it's Apple's own documented restriction, and it's
the reason the original push+widget plan (still described at the bottom of this file)
isn't buildable without a $99/year paid account. Rather than block the whole MVP on
that purchase, here's the free-tier substitute — genuinely simpler to build, not just
a workaround.

## The substitute

- **Delivery mechanism: a live Postgres subscription, not a push notification.**
  `CapsuleRepository.subscribeToCapsules(...)` (Supabase Realtime) fires the instant a
  capsule's `status` column changes, as long as the recipient's app is open and
  subscribed. For a demo where both phones are on the table in front of judges, this
  is _more_ reliable than push, not less — no APNs propagation delay, no provisioning
  profile to get wrong.
- **The widget: an in-app screen, not a home-screen WidgetKit extension.**
  Build `InAppWidgetPreviewView` (SwiftUI, lives in `OrbitApp/Views/`, not a separate
  target) styled to look exactly like the intended home-screen widget — same
  approach/arrival visual, same colors. It reads live state from whatever's already
  driving the rest of the UI (a `@State`/`@Published` array updated by the Realtime
  subscription above), so there's no App Group, no shared container, no cross-process
  anything to get working. For a demo, "here's the moment the widget shows" reads the
  same to a judge whether it's rendered by WidgetKit or by a SwiftUI view inside the
  app.
- **Auth: Supabase Auth's anonymous sign-in, not Sign in with Apple.** No entitlement
  needed at all; upgrade to a real auth method later if this goes anywhere past a
  demo.

## What you lose, honestly

The in-app "widget" won't actually live on the home screen or lock screen — it only
shows while the app itself is open. That's a real gap between this and the original
vision, not a cosmetic one. It's the right trade for a free, fast MVP; it's not the
final answer. Say so in the demo rather than implying it's a real OS widget.

## When you have a paid account: the original plan (unchanged, do this instead)

1. **Firebase console** (or whichever push provider): enable Cloud Messaging, upload
   your APNs Auth Key.
2. **Xcode capabilities** (App target): Push Notifications; Background Modes → Remote
   notifications; App Groups.
3. **Widget Extension target**: add it, share the App Group, read live state from
   `UserDefaults(suiteName:)` instead of the in-app view's local state.
4. **Notification Service Extension target**: add it, attach the preview image to the
   rich push (`NotificationServiceExtension/NotificationService.swift` already has
   this written — it was deferred, not deleted).
5. Test on real devices — push, including silent pushes, is unreliable or unsupported
   on Simulator regardless of account type.
