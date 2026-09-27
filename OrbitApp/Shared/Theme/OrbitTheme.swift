import SwiftUI
import UIKit

/// Design tokens from docs/STYLE_SHEET.md (style sheet v5, matte, locked).
/// Screens should reference these tokens, not hardcoded hex values, so a
/// future palette tweak is a one-file change. Add this file to the App,
/// Widget, and Notification Service Extension targets (same as the rest of
/// Shared/) since the widget needs these colors too.
extension Color {
    // Space / chrome
    static let spaceDeep = Color(hex: "#14152E")
    static let panelNavy = Color(hex: "#20244F")
    static let cardWhite = Color(hex: "#FFFFFF")
    static let navSurfaceDark = Color(hex: "#FFFFFF")
    static let navSurfaceLight = Color(hex: "#F5F6FB")
    static let navIconInactive = Color(hex: "#D6D9F0")
    static let accentBlue = Color(hex: "#3D5AFE")
    static let textOnDark = Color(hex: "#FFFFFF")
    static let textOnDarkMuted = Color(hex: "#A9ADD6")
    static let textOnLight = Color(hex: "#1A1B3D")
    static let textOnLightMuted = Color(hex: "#6E7191")
    static let dividerLight = Color(hex: "#EDEEF7")
    static let hullCap = Color(hex: "#343B57")
    static let hullCapLight = Color(hex: "#4A5170")
    static let cloudGray = Color(hex: "#C9C3D9")
    static let skyGlass = Color(hex: "#7CC4FF")

    // Recolor set — one flat hue per planet / ship / package instance.
    // Named `orbit*` to avoid colliding with SwiftUI's own `Color.gold`-style
    // extensions some projects add elsewhere.
    static let orbitMagenta = Color(hex: "#E0399B")
    static let orbitViolet  = Color(hex: "#8452D6")
    static let orbitSeafoam = Color(hex: "#3FD9B0")
    static let orbitGold    = Color(hex: "#F2A93B")
    static let orbitEmber   = Color(hex: "#E8432E")
    static let orbitLime    = Color(hex: "#C6E23C")

    static let recolorHues: [Color] = [.orbitMagenta, .orbitViolet, .orbitSeafoam, .orbitGold, .orbitEmber, .orbitLime]

    // A capsule's INSIDE (the unboxing reveal / scrapbook page) is a
    // deliberately different register from the rest of the app's matte-navy
    // chrome — a warm handmade paper page, not another space screen. These
    // two are a best-guess kraft palette, not yet in the locked style sheet
    // — swap for the real Redraft-generated values once they exist.
    static let kraftPaper = Color(hex: "#F4E8D0")
    static let inkBrown = Color(hex: "#5B4632")

    /// Accepts "#RRGGBB" or "RRGGBB".
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Mixes toward white — the light half of every two-tone flat split
    /// (nose cone, ship body, window glass). Per the style sheet: use this
    /// to fill a second, separately shaped/clipped flat region — never as
    /// an actual gradient fill.
    func lightened(by amount: Double) -> Color {
        mixed(toward: .white, amount: amount)
    }

    /// Mixes toward black — a planet's crescent/craters (~20% per the
    /// style sheet).
    func darkened(by amount: Double) -> Color {
        mixed(toward: .black, amount: amount)
    }

    private func mixed(toward target: Color, amount: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(target).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * amount),
            green: Double(g1 + (g2 - g1) * amount),
            blue: Double(b1 + (b2 - b1) * amount)
        )
    }
}

extension Font {
    /// Display font — "Orbit", "Capsule landed". Requires Baloo 2 (or
    /// Fredoka) added as a font file and registered in Info.plist — see
    /// OrbitApp/Resources/README_ASSETS.md. VERSION NOTE: the exact
    /// PostScript name (what `.custom` needs) depends on how the specific
    /// font file identifies itself — confirm via Font Book / Font Inspector
    /// once the real file is added rather than assuming "Baloo2-Bold" below
    /// is exactly right.
    static func orbitDisplay(_ size: CGFloat) -> Font {
        custom("Baloo2-Bold", size: size, fallback: .system(size: size, weight: .heavy, design: .rounded))
    }
    /// UI headings, buttons, nav labels.
    static func orbitHeading(_ size: CGFloat) -> Font {
        custom("Poppins-SemiBold", size: size, fallback: .system(size: size, weight: .bold, design: .rounded))
    }
    /// Body text, captions.
    static func orbitBody(_ size: CGFloat) -> Font {
        custom("Poppins-Regular", size: size, fallback: .system(size: size, weight: .medium, design: .rounded))
    }
    /// Handwritten captions on the scrapbook reveal page only — not used
    /// anywhere in the app's matte-navy chrome. "Caveat" in the HTML
    /// prototype; swap for whatever hand-lettered font Design settles on.
    static func orbitHandwritten(_ size: CGFloat) -> Font {
        custom("Caveat-SemiBold", size: size, fallback: .system(size: size, weight: .semibold, design: .serif).italic())
    }

    /// `.custom` silently falls back to plain regular system text when the
    /// font file isn't bundled — which flattened every heading. Until the
    /// real files are added (Resources/README_ASSETS.md), fall back to a
    /// rounded/weighted system font that keeps the hierarchy intact.
    private static func custom(_ name: String, size: CGFloat, fallback: Font) -> Font {
        UIFont(name: name, size: size) != nil ? .custom(name, size: size) : fallback
    }
}
