# Orbit — style sheet v5 (final, matte)

Locked version. Source of truth for `Shared/Theme/OrbitTheme.swift` (Swift tokens)
and `orbit_prototype.html` (the interactive HTML mockup) — if this doc changes, both
of those need updating too.

> **v6 depth pass (2026-09-26) — overrides §3's "no gradients / no glow" rule.**
> The team asked for a more dimensional, gamified feel in the final build. Palette,
> typography, shapes, navigation, and screen layouts below are unchanged; what changed:
> - **Planets** (`ShadedPlanet`): lit top-left with radial falloff, terminator shadow,
>   specular highlight, rim light, soft hue glow; surface spots rotate with the sphere.
> - **Packages** (`GiftBoxView`): lit/shadowed faces, highlighted lid edge, contact shadow.
>   Recolorable via `OrbitHue`; stored per capsule in `CapsuleLayout.packageColor`.
> - **Chrome**: cards get a subtle top highlight + drop shadow (`.orbitCard()`); primary
>   buttons are raised pills that press into a darker base (`OrbitPillButtonStyle`).
> - **Background**: `StarfieldBackground` — diamond stars still, but twinkling at three
>   parallax depths, plus one soft navy glow near the top.
> - **Motion everywhere**: hovering rocket, wobbling packages, countdown liftoff, shake →
>   burst → reveal unboxing, confetti, XP/level-up toasts, haptics (toggle in Settings).
> - **Art**: Design's SVGs live in `Assets.xcassets` (cropped, metadata stripped); the
>   rocket is split into `rocket_body` + `rocket_flame` so the flame can animate.

---

## 1. Color palette

### Space / chrome
| Token | Hex | Used for |
|---|---|---|
| `spaceDeep` | `#14152E` | Screen background on all space scenes (flat fill) |
| `panelNavy` | `#20244F` | Raised dark panels, launchpad structure, Create screen background |
| `cardWhite` | `#FFFFFF` | Package-reveal letter sheet, Settings screen background |
| `navSurfaceDark` | `#FFFFFF` | Bottom nav bar on dark screens |
| `navSurfaceLight` | `#F5F6FB` | Bottom nav bar on the white Settings screen |
| `navIconInactive` | `#D6D9F0` | Inactive nav icon |
| `accentBlue` | `#3D5AFE` | Primary buttons, active nav icon, links, home planet |
| `textOnDark` | `#FFFFFF` | Primary text on space background |
| `textOnDarkMuted` | `#A9ADD6` | Secondary text on space background |
| `textOnLight` | `#1A1B3D` | Primary text on white background |
| `textOnLightMuted` | `#6E7191` | Secondary text on white background |
| `dividerLight` | `#EDEEF7` | Row dividers on white screens (Settings) |
| `hullCap` | `#343B57` | Fixed nose cone / engine collar color on every ship, regardless of hull hue |
| `hullCapLight` | `#4A5170` | Lighter flat half of the two-tone nose cone split |

### Recolor set (one flat hue per planet / ship / package instance)
| Token | Hex |
|---|---|
| `magenta` | `#E0399B` |
| `violet` | `#8452D6` |
| `seafoam` | `#3FD9B0` |
| `gold` | `#F2A93B` |
| `ember` | `#E8432E` |
| `lime` | `#C6E23C` |

Every recolorable shape uses exactly one flat hue. If a second tone is needed for depth
(a crater, a shadow band), use the same hue at roughly 20% darker as its own flat shape
— never a gradient blend.

---

## 2. Typography

| Role | Font | Weight |
|---|---|---|
| Display / hero ("Orbit", "Capsule landed") | Baloo 2 (or Fredoka) | Bold/800 |
| UI headings, buttons, nav labels | Poppins | SemiBold/600 |
| Body text, captions | Poppins or Inter | Regular/400 |

---

## 3. Shape & illustration language

Flat solid fills throughout. No gradients, no glow/halo, no glossy highlight dots. Depth
comes from adding distinct flat shapes (a darker crescent, extra craters, a ring band),
not from shading an existing shape.

**Planets/moons** — circle, one flat hue. Optional: a flat darker crescent for volume,
flat darker craters, or 1–2 flat ring bands passing behind/in front.

**Ships — classic rocket silhouette:**
| Part | Shape | Color |
|---|---|---|
| Nose cone | Tall narrow rounded cone, top ~20% of ship height | Two-tone flat split down the middle: `hullCapLight` (left half) / `hullCap` (right half) — fixed on every ship, not recolored |
| Body | Tall rounded cylinder, ~55% of ship height, does not taper | Two-tone flat split down the middle: lighter tint of `[recolor hue]` (left half) / base `[recolor hue]` (right half) |
| Fins ×2 | Larger swept-back triangular fins at the base, angled outward | Flat `cloudGray` (#C9C3D9) — fixed, not recolored |
| Window | Circle in the upper-body third, ~35% of body width | Ring: `hullCap` (fixed) · Glass: two-tone flat split, lighter `sky` tint (top-left) / base `sky` (#7CC4FF, bottom-right) |
| Engine collar | Short flat band where fins meet the body | Flat `hullCap` (fixed) |
| Flame (launch variant only) | Two nested tapering flame shapes, point down | Outer: flat `ember` (#E8432E) · Inner: flat `gold` (#F2A93B) |

The two-tone vertical split (light half / base half of the same hue) is the one shading
trick used on ships — same rule as the planet crescent, just applied as a straight
vertical line instead of a curve. Nose cone, fins, and window ring stay fixed colors on
every ship so only the body and window glass carry the recolor identity.

**Packages** — pillow-box silhouette in one flat hue, ribbon/bow in flat white (or flat
gold for contrast on light packages).
**Background** — flat navy, flat 4-point diamond stars (white or accent hue), no soft
nebula glow.
**UI chrome** — flat cards, pill buttons and pill nav bar, thin flat dividers instead of
shadows for separation.

---

## 4. Navigation

Bottom tab bar, 4 tabs: **Home · Create · Galaxy · Settings**. Nav bar is a floating
pill: `navSurfaceDark` on dark screens, `navSurfaceLight` on the white Settings screen.
Active icon `accentBlue`, inactive `navIconInactive`.

Outside the tab bar: **Login** (entry point) and **Package opening** (full-screen
takeover, launched from Home).

---

## 5. Screen specs

### Login
Flat `spaceDeep` background, flat stars, one flat-colored planet anchored in a bottom
corner (no glow). "Orbit" in display font, centered. Single "Sign in with Apple" pill
button, `accentBlue`.

### Home (Launchpad)
Flat `spaceDeep` background. Launchpad structure in `panelNavy` (gantry tower +
platform), a flat `accentBlue`-ringed landing marker on the platform. Docked ship
rendered in one recolor hue, sitting on the pad. Waiting packages rendered near the pad
in their own recolor hues. "Send a package" pill CTA (`accentBlue`) above the nav bar.

### Create
Background `panelNavy`. Layout, top to bottom: recipient row, package color swatches,
a 2×2 attach grid (Photo, Voice, Video, Note), "Launch" pill CTA pinned to the bottom.

### Galaxy
Flat `spaceDeep` background. Home planet at center in `accentBlue`. Other senders'
planets scattered at varying distance, each its own recolor hue. Faint flat dashed
orbit-path circles. A small flat ship-in-transit shape between two planets with 1–2
small flat dot "trail" marks.

### Settings
Background `cardWhite`. Simple vertical list: Account, Notifications, Sound & haptics,
About Orbit — each row is a text label + a ">" chevron, separated by `dividerLight`
hairlines. Nav bar uses `navSurfaceLight`.

### Package opening (full-screen takeover)
1. **Focus** — package scales up and centers, rest of scene dims
2. **Shake** — brief rotation-wiggle, ~1–2 seconds
3. **Burst** — lid flies off at an angle, flat-colored confetti bits scatter
4. **Reveal** — a `cardWhite` sheet slides up from the bottom and takes over the full
   screen: sender name, one flat-colored content block (photo/video placeholder), and
   their message text
5. Exit via close button or swipe-down, back to Home

---

## 6. Mascot — Cosmo

Chibi proportions, helmet ≈ 55% of height, body ≈ 45%. All-white suit (`cardWhite`),
flat `sky`-blue visor circle with a white ring, small flat gold cheek dot (`#F2A93B` at
reduced opacity). Backpack and boots share one recolor hue (can vary by context).

**Poses (same base shapes, limbs/eyes change only):**
- `wave` — one arm raised, greetings/tutorial intros
- `pack` — leaning forward, arms down, loading states
- `sleep` — arms tucked, eyes closed, empty states
- `cheer` — both arms up, paired with confetti, celebratory moments

---

## 7. Addendum — from the Redraft mockup round (supersedes anywhere it conflicts above)

Two updates, based on the actual matte mockups generated in the asset-prompt session
(not yet formalized into a v6 doc, so flagging both here explicitly):

- **Package shape is a capsule, not a gift box.** A vertical pill — rounded top and
  bottom, straight sides, one flat recolor hue — with a single horizontal seam band
  in a lighter tint of the same hue about 40% down, and a small soft highlight circle
  near the top. No ribbon, no bow. This is a better fit for the product's actual name
  than the gift-box silhouette earlier drafts used.
- **The capsule's inside (the opening-reveal page) is a different register on
  purpose:** a warm handmade scrapbook page, not another matte-navy space screen.
  Cream/kraft paper background, a couple of overlapping "polaroid" photo blocks
  (white border, drop shadow, slightly rotated in opposite directions), a small
  washi-tape accent strip, and a handwritten-style caption in a warm ink brown —
  contrast is the point: the ship/delivery layer is techy and cool-toned, what's
  actually inside is warm and tactile. Exact kraft/ink hex values here are a
  placeholder (`#F4E8D0` paper, `#5B4632` ink) pending the real Redraft-generated
  asset — see `Shared/Theme/OrbitTheme.swift`.
- A short "Capsule landed!" confirmation beat appears briefly around the burst
  moment, before the scrapbook page finishes sliding up.
