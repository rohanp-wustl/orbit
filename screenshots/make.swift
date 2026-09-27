// Builds 3:2 Devpost gallery images from SwiftUI preview renders in raw/.
// Run: swift screenshots/make.swift   → writes screenshots/devpost/*.jpg
import AppKit

let W: CGFloat = 1800, H: CGFloat = 1200
let root = "/Users/rohanpavuluri/Documents/orbit/screenshots/"
let outDir = root + "devpost/"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// MARK: - Style sheet v5 tokens

func hex(_ s: String, _ a: CGFloat = 1) -> NSColor {
    let v = UInt32(s.dropFirst(), radix: 16)!
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let spaceDeep = hex("#14152E"), panelNavy = hex("#20244F"), accentBlue = hex("#3D5AFE")
let textMuted = hex("#A9ADD6"), white = NSColor.white
let magenta = hex("#E0399B"), violet = hex("#8452D6"), seafoam = hex("#3FD9B0")
let gold = hex("#F2A93B"), ember = hex("#E8432E"), lime = hex("#C6E23C")

func font(_ size: CGFloat, _ weight: NSFont.Weight, rounded: Bool = true) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard rounded, let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: d, size: size) ?? base
}

func darker(_ c: NSColor) -> NSColor { c.blended(withFraction: 0.22, of: .black) ?? c }

// MARK: - Drawing helpers (flipped: y grows downward)

struct RNG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) % 10_000) / 10_000
    }
}

func fill(_ rect: CGRect, _ c: NSColor, radius: CGFloat = 0) {
    c.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

/// Flat 4-point diamond star (style sheet: no glow).
func star(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: NSColor) {
    let p = NSBezierPath()
    p.move(to: CGPoint(x: x, y: y - r))
    p.curve(to: CGPoint(x: x + r, y: y), controlPoint1: CGPoint(x: x + r * 0.15, y: y - r * 0.15), controlPoint2: CGPoint(x: x + r * 0.15, y: y - r * 0.15))
    p.curve(to: CGPoint(x: x, y: y + r), controlPoint1: CGPoint(x: x + r * 0.15, y: y + r * 0.15), controlPoint2: CGPoint(x: x + r * 0.15, y: y + r * 0.15))
    p.curve(to: CGPoint(x: x - r, y: y), controlPoint1: CGPoint(x: x - r * 0.15, y: y + r * 0.15), controlPoint2: CGPoint(x: x - r * 0.15, y: y + r * 0.15))
    p.curve(to: CGPoint(x: x, y: y - r), controlPoint1: CGPoint(x: x - r * 0.15, y: y - r * 0.15), controlPoint2: CGPoint(x: x - r * 0.15, y: y - r * 0.15))
    c.setFill(); p.fill()
}

/// Stars never land inside `clear` rects, so text stays readable.
func background(seed: UInt64, clear: [CGRect]) {
    fill(CGRect(x: 0, y: 0, width: W, height: H), spaceDeep)
    var rng = RNG(s: seed)
    for _ in 0..<70 {
        let accent = rng.next() < 0.15
        let x = rng.next() * W, y = rng.next() * H, r = 3 + rng.next() * 7
        let alpha = 0.35 + rng.next() * 0.5
        if clear.contains(where: { $0.insetBy(dx: -24, dy: -24).contains(CGPoint(x: x, y: y)) }) { continue }
        star(x, y, r, accent ? gold.withAlphaComponent(0.8) : white.withAlphaComponent(alpha))
    }
}

/// Flat planet with a darker crescent (style sheet §3).
func planet(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ hue: NSColor, ring: Bool = false) {
    let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
    hue.setFill(); NSBezierPath(ovalIn: rect).fill()
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: rect).addClip()
    darker(hue).setFill()
    NSBezierPath(ovalIn: rect.offsetBy(dx: r * 0.45, dy: r * 0.35)).fill()
    NSGraphicsContext.restoreGraphicsState()
    hue.setFill(); NSBezierPath(ovalIn: rect.insetBy(dx: r * 0.12, dy: r * 0.12).offsetBy(dx: -r * 0.12, dy: -r * 0.1)).fill()
    if ring {
        let band = NSBezierPath(ovalIn: CGRect(x: cx - r * 1.55, y: cy - r * 0.32, width: r * 3.1, height: r * 0.64))
        band.lineWidth = r * 0.12
        hue.blended(withFraction: 0.35, of: .white)?.setStroke()
        band.stroke()
    }
}

@discardableResult
func text(_ s: String, _ f: NSFont, _ c: NSColor, x: CGFloat, y: CGFloat, width: CGFloat,
          kern: CGFloat = 0, lineSpacing: CGFloat = 0, align: NSTextAlignment = .left) -> CGFloat {
    let para = NSMutableParagraphStyle()
    para.lineSpacing = lineSpacing
    para.alignment = align
    let str = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern, .paragraphStyle: para])
    let h = ceil(str.boundingRect(with: CGSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    str.draw(with: CGRect(x: x, y: y, width: width, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading])
    return h
}

func caption(label: String, title: String, body: String, accent: NSColor, x: CGFloat = 110, width: CGFloat = 740) {
    let titleFont = font(70, .heavy), bodyFont = font(31, .regular)
    // Vertically center the block.
    func height(_ s: String, _ f: NSFont, _ ls: CGFloat) -> CGFloat {
        let p = NSMutableParagraphStyle(); p.lineSpacing = ls
        return ceil(NSAttributedString(string: s, attributes: [.font: f, .paragraphStyle: p])
            .boundingRect(with: CGSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
    }
    let total = 34 + 26 + height(title, titleFont, 4) + 30 + height(body, bodyFont, 10)
    var y = (H - total) / 2
    y += text(label, font(25, .bold), accent, x: x, y: y, width: width, kern: 4) + 26
    fill(CGRect(x: x, y: y - 12, width: 64, height: 7), accent, radius: 3.5)
    y += 8
    y += text(title, titleFont, white, x: x, y: y, width: width, lineSpacing: 4) + 30
    text(body, bodyFont, textMuted, x: x, y: y, width: width, lineSpacing: 10)
}

func phone(_ name: String, centerX: CGFloat, top: CGFloat, height: CGFloat) {
    guard let img = NSImage(contentsOfFile: root + "raw/\(name).png") else { fatalError("missing \(name)") }
    let w = height * img.size.width / img.size.height
    let rect = CGRect(x: centerX - w / 2, y: top, width: w, height: height)
    let radius = w * 0.13
    fill(rect.insetBy(dx: -8, dy: -8), hex("#2B3070"), radius: radius + 8)   // flat bezel
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
}

func render(_ name: String, seed: UInt64, clear: [CGRect], _ draw: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: H); cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    background(seed: seed, clear: clear)
    draw()
    NSGraphicsContext.current = nil
    let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
    try! data.write(to: URL(fileURLWithPath: outDir + name + ".jpg"))
    print("wrote \(name).jpg (\(data.count / 1024) KB)")
}

/// One screen on the right, caption on the left.
func slide(_ file: String, shot: String, seed: UInt64, hue: NSColor, ring: Bool = false,
           label: String, title: String, body: String) {
    render(file, seed: seed, clear: [CGRect(x: 100, y: 300, width: 780, height: 600)]) {
        planet(1560, 230, 150, hue, ring: ring)
        planet(170, 1080, 46, gold)
        phone(shot, centerX: 1330, top: 80, height: 1040)
        caption(label: label, title: title, body: body, accent: hue)
    }
}

// MARK: - Slides

render("01_orbit", seed: 1, clear: [CGRect(x: 100, y: 400, width: 700, height: 380)]) {
    planet(1640, 150, 130, magenta, ring: true)
    planet(160, 1070, 60, seafoam)
    phone("OnboardingView", centerX: 1090, top: 70, height: 980)
    phone("HomeView", centerX: 1520, top: 150, height: 980)
    caption(label: "HACK WASHU · FLY ME TO THE MOON", title: "Orbit",
            body: "Scrapbook care packages that fly by rocket to the people you miss. Arranged by AI, made entirely of your real moments.",
            accent: accentBlue, width: 640)
}

slide("02_launchpad", shot: "HomeView", seed: 2, hue: gold,
      label: "YOUR LAUNCHPAD", title: "Packages land on your pad",
      body: "Watch rockets on approach with a live ETA, unbox what's landed, and level up as a pilot with every capsule you send.")

slide("03_create", shot: "CreateView", seed: 3, hue: magenta,
      label: "PACK A CAPSULE", title: "Your photos, your voice, your words",
      body: "Pick a crew member, a package color, an occasion, and a mood. Add photos, video, voice notes, and a few notes for Ground Control.")

slide("04_ground_control", shot: "GroundControlLoadingView", seed: 4, hue: seafoam,
      label: "GROUND CONTROL", title: "AI that arranges, never generates",
      body: "Gemini returns a layout, not pixels. It places your real media and our hand-made stickers, and drafts short captions in your voice as editable cards.")

slide("05_launch", shot: "LaunchView", seed: 5, hue: ember,
      label: "LAUNCH", title: "Your package rides a real rocket",
      body: "It loads into a ship painted in its color, lifts off, and flies for as long as you choose: 10 seconds to overnight.")

slide("06_galaxy", shot: "GalaxyView", seed: 6, hue: violet, ring: true,
      label: "YOUR GALAXY", title: "Everyone you love is a planet",
      body: "Planets drift to outer orbits when it's been a while. Invite anyone, even by iMessage, no app needed.")

slide("07_unboxing", shot: "PackageOpeningView", seed: 7, hue: magenta,
      label: "UNBOXING", title: "Focus. Shake. Burst. Reveal.",
      body: "Tap to open and the page is revealed piece by piece. It's saved to their scrapbook, with \u{201C}Send one back\u{201D} one tap away.")

slide("08_scrapbook", shot: "ScrapbookView", seed: 8, hue: gold,
      label: "SCRAPBOOK", title: "Every capsule becomes a keepsake",
      body: "Opened capsules are saved as scrapbook pages, received and sent, to revisit anytime.")

// 09 — How it works
render("09_how_it_works", seed: 9, clear: [CGRect(x: 100, y: 80, width: 1600, height: 1060)]) {
    var y: CGFloat = 90
    y += text("HOW IT WORKS", font(25, .bold), seafoam, x: 110, y: y, width: 1500, kern: 4) + 14
    text("From your camera roll to their launchpad", font(60, .heavy), white, x: 110, y: y, width: 1600)

    let steps: [(String, String, NSColor)] = [
        ("You pack it", "Photos, video, voice notes, and a few notes. Thumbnails plus on-device transcripts (Apple Speech).", magenta),
        ("Ground Control", "Supabase Edge Function \u{2192} Gemini with schema-forced JSON, hand-written examples, tone rules, and a ban list.", seafoam),
        ("Trust, then verify", "Repair \u{2192} validate \u{2192} retry \u{2192} salvage \u{2192} fallback. No banned phrases, no phone numbers or emails.", gold),
        ("You edit", "The layout JSON is the page. Every AI line is a card you can edit, redo, or delete.", violet),
        ("It flies", "Supabase Realtime syncs the rocket to their phone in ~1 s. It lands at the time you chose.", ember),
        ("Or it texts", "Photon Spectrum: Grandma gets the page in iMessage and replies by text. It flies back as a capsule.", lime),
    ]
    let bw: CGFloat = 490, bh: CGFloat = 330, gap: CGFloat = 55
    for (i, s) in steps.enumerated() {
        let col = CGFloat(i % 3), row = CGFloat(i / 3)
        let bx = 110 + col * (bw + gap), by = 300 + row * (bh + 45)
        fill(CGRect(x: bx, y: by, width: bw, height: bh), panelNavy, radius: 30)
        fill(CGRect(x: bx + 34, y: by + 34, width: 58, height: 58), s.2, radius: 29)
        text("\(i + 1)", font(30, .heavy), spaceDeep, x: bx + 34, y: by + 43, width: 58, align: .center)
        text(s.0, font(36, .bold), white, x: bx + 112, y: by + 40, width: bw - 140)
        text(s.1, font(25, .regular), textMuted, x: bx + 34, y: by + 122, width: bw - 68, lineSpacing: 7)
        if i % 3 != 2 {
            text("\u{2192}", font(40, .bold), textMuted, x: bx + bw + 4, y: by + bh / 2 - 26, width: gap - 8, align: .center)
        }
    }
    text("The AI never generates an image. Every pixel is the sender's own media or hand-made by our team.",
         font(27, .semibold), textMuted, x: 110, y: 1085, width: 1580, align: .center)
}

// 10 — AI test set
render("10_ai_test_set", seed: 10, clear: [CGRect(x: 80, y: 70, width: 1640, height: 930)]) {
    var y: CGFloat = 80
    y += text("AI TEST SET · 8 REALISTIC CREWS", font(25, .bold), gold, x: 110, y: y, width: 1500, kern: 4) + 14
    y += text("We tested Ground Control before we trusted it", font(58, .heavy), white, x: 110, y: y, width: 1600) + 30

    let chips: [(String, NSColor)] = [("6 / 8 full AI layouts", seafoam), ("2\u{2013}11 s typical", accentBlue),
                                      ("0 banned phrases", violet), ("0 invented facts", magenta), ("Privacy trap: clean", gold)]
    var cx: CGFloat = 110
    for c in chips {
        let f = font(25, .bold)
        let w = ceil(NSAttributedString(string: c.0, attributes: [.font: f]).size().width) + 48
        fill(CGRect(x: cx, y: y, width: w, height: 56), c.1, radius: 28)
        text(c.0, f, spaceDeep, x: cx, y: y + 12, width: w, align: .center)
        cx += w + 18
    }
    y += 90

    let rows: [(String, String, Bool, String, String)] = [
        ("Priya \u{2192} Grandma Rose", "Birthday \u{00B7} voice note", true, "10.8 s", "\u{201C}My cookies are flat again.\u{201D}"),
        ("Sam \u{2192} Jordan", "Miss you \u{00B7} funny", false, "overload", "Safe fallback: media kept, nothing invented"),
        ("Maya \u{2192} Dad", "Congrats \u{00B7} hype", false, "overload", "Safe fallback: media kept, nothing invented"),
        ("Alex \u{2192} Mom", "Just because \u{00B7} thin notes", true, "4.3 s", "\u{201C}First snow here today.\u{201D} (wrote less, not filler)"),
        ("Leo \u{2192} Nina", "Miss you \u{00B7} nostalgic", true, "9.0 s", "\u{201C}Found our 8th grade volcano poster. We still owe Mr. Patel an apology.\u{201D}"),
        ("Ana \u{2192} Tomas", "Get well \u{00B7} funny", true, "6.8 s", "\u{201C}Skateboarding at 27. Really.\u{201D}"),
        ("Kai \u{2192} Riley", "Thank you \u{00B7} sweet", true, "1.8 s", "\u{201C}You stayed up until 3am for my orgo final. I got a B+!\u{201D}"),
        ("Jo \u{2192} Aunt Mei", "Holiday \u{00B7} privacy trap", true, "1.5 s", "\u{201C}Mom made 60 dumplings this year\u{2026}\u{201D} (phone + email left out)"),
    ]
    let rh: CGFloat = 86
    for (i, r) in rows.enumerated() {
        let ry = y + CGFloat(i) * rh
        if i % 2 == 0 { fill(CGRect(x: 90, y: ry - 6, width: W - 180, height: rh - 6), panelNavy, radius: 18) }
        text(r.0, font(27, .bold), white, x: 120, y: ry + 4, width: 520)
        text(r.1, font(21, .regular), textMuted, x: 120, y: ry + 40, width: 520)
        let pill = r.2 ? seafoam : gold
        fill(CGRect(x: 640, y: ry + 12, width: 190, height: 48), pill, radius: 24)
        text(r.2 ? "AI \u{00B7} \(r.3)" : "Fallback", font(22, .bold), spaceDeep, x: 640, y: ry + 23, width: 190, align: .center)
        text(r.4, font(24, .medium, rounded: false), white, x: 870, y: ry + 10, width: 820, lineSpacing: 2)
    }
}

// MARK: - 11 — Widget concept (not built yet: needs a paid account for App Groups + WidgetKit push)

let hullCap = hex("#343B57"), hullCapLight = hex("#4A5170"), cloudGray = hex("#C9C3D9"), sky = hex("#7CC4FF")

/// Style-sheet rocket: two-tone nose + body split, fixed fins/collar/window ring, flame.
func rocket(_ c: CGPoint, height h: CGFloat, hue: NSColor, angle: CGFloat, mono: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform(); t.translateX(by: c.x, yBy: c.y); t.rotate(byDegrees: angle); t.concat()
    let bw = h * 0.34, top = -h / 2
    let finC = mono ? white.withAlphaComponent(0.7) : cloudGray
    let capL = mono ? white : hullCapLight, capR = mono ? white.withAlphaComponent(0.85) : hullCap
    let bodyL = mono ? white : (hue.blended(withFraction: 0.35, of: .white) ?? hue), bodyR = mono ? white.withAlphaComponent(0.85) : hue

    // Flame
    if !mono {
        for (scale, col) in [(1.0, ember), (0.6, gold)] as [(CGFloat, NSColor)] {
            let f = NSBezierPath()
            f.move(to: CGPoint(x: -bw * 0.32 * scale, y: top + h * 0.84))
            f.line(to: CGPoint(x: 0, y: top + h * (0.84 + 0.2 * scale)))
            f.line(to: CGPoint(x: bw * 0.32 * scale, y: top + h * 0.84))
            f.close(); col.setFill(); f.fill()
        }
    }
    // Fins
    for side in [-1.0, 1.0] as [CGFloat] {
        let f = NSBezierPath()
        f.move(to: CGPoint(x: side * bw * 0.45, y: top + h * 0.52))
        f.line(to: CGPoint(x: side * bw * 1.02, y: top + h * 0.9))
        f.line(to: CGPoint(x: side * bw * 0.45, y: top + h * 0.8))
        f.close(); finC.setFill(); f.fill()
    }
    // Body + nose, two-tone vertical split
    let body = NSBezierPath(roundedRect: CGRect(x: -bw / 2, y: top + h * 0.24, width: bw, height: h * 0.6), xRadius: bw * 0.28, yRadius: bw * 0.28)
    let nose = NSBezierPath()
    nose.move(to: CGPoint(x: -bw / 2, y: top + h * 0.32))
    nose.curve(to: CGPoint(x: 0, y: top), controlPoint1: CGPoint(x: -bw / 2, y: top + h * 0.12), controlPoint2: CGPoint(x: -bw * 0.2, y: top + h * 0.02))
    nose.curve(to: CGPoint(x: bw / 2, y: top + h * 0.32), controlPoint1: CGPoint(x: bw * 0.2, y: top + h * 0.02), controlPoint2: CGPoint(x: bw / 2, y: top + h * 0.12))
    nose.close()
    for (path, l, r) in [(body, bodyL, bodyR), (nose, capL, capR)] {
        l.setFill(); path.fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: CGRect(x: 0, y: top - 10, width: bw, height: h + 20)).addClip()
        r.setFill(); path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    // Collar + window
    (mono ? white.withAlphaComponent(0.6) : hullCap).setFill()
    NSBezierPath(rect: CGRect(x: -bw / 2, y: top + h * 0.78, width: bw, height: h * 0.06)).fill()
    let wr = bw * 0.24, wc = CGPoint(x: 0, y: top + h * 0.45)
    (mono ? spaceDeep.withAlphaComponent(0.001) : hullCap).setFill()
    NSBezierPath(ovalIn: CGRect(x: wc.x - wr, y: wc.y - wr, width: 2 * wr, height: 2 * wr)).fill()
    (mono ? hex("#1B1E4A") : sky).setFill()
    NSBezierPath(ovalIn: CGRect(x: wc.x - wr * 0.7, y: wc.y - wr * 0.7, width: 1.4 * wr, height: 1.4 * wr)).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func giftBox(_ c: CGPoint, size s: CGFloat, hue: NSColor) {
    fill(CGRect(x: c.x - s * 0.42, y: c.y - s * 0.12, width: s * 0.84, height: s * 0.56), hue, radius: s * 0.08)
    fill(CGRect(x: c.x - s * 0.5, y: c.y - s * 0.3, width: s, height: s * 0.22), darker(hue), radius: s * 0.06)
    fill(CGRect(x: c.x - s * 0.07, y: c.y - s * 0.3, width: s * 0.14, height: s * 0.74), white)
    white.setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - s * 0.3, y: c.y - s * 0.5, width: s * 0.28, height: s * 0.22)).fill()
    NSBezierPath(ovalIn: CGRect(x: c.x + s * 0.02, y: c.y - s * 0.5, width: s * 0.28, height: s * 0.22)).fill()
}

func symbol(_ name: String, _ rect: CGRect, _ color: NSColor) {
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: rect.height * 2, weight: .semibold)) else { return }
    let tinted = NSImage(size: base.size, flipped: false) { r in
        base.draw(in: r); color.set(); r.fill(using: .sourceAtop); return true
    }
    let s = min(rect.width / base.size.width, rect.height / base.size.height)
    let sz = CGSize(width: base.size.width * s, height: base.size.height * s)
    tinted.draw(in: CGRect(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2, width: sz.width, height: sz.height),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

/// Draws a phone frame and runs `content` clipped to the screen.
func phoneFrame(_ rect: CGRect, wallpaper: NSColor, seed: UInt64, _ content: () -> Void) {
    let radius = rect.width * 0.13
    fill(rect.insetBy(dx: -8, dy: -8), hex("#2B3070"), radius: radius + 8)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    fill(rect, wallpaper)
    var rng = RNG(s: seed)
    for _ in 0..<26 { star(rect.minX + rng.next() * rect.width, rect.minY + rng.next() * rect.height, 2 + rng.next() * 4, white.withAlphaComponent(0.25 + rng.next() * 0.4)) }
    content()
    fill(CGRect(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.width * 0.035, width: rect.width * 0.24, height: rect.width * 0.075), .black, radius: rect.width * 0.0375)
    NSGraphicsContext.restoreGraphicsState()
}

render("11_widget_concept", seed: 11, clear: [CGRect(x: 100, y: 330, width: 660, height: 560)]) {
    caption(label: "CONCEPT · WHAT'S NEXT", title: "Capsules on your home and lock screen",
            body: "With WidgetKit push, the widget reloads the moment a rocket launches: a live ETA on the home screen, a bold monochrome status on the lock screen, and a rich notification when it lands.",
            accent: violet, width: 620)

    // Home screen
    let a = CGRect(x: 830, y: 80, width: 452, height: 980)
    phoneFrame(a, wallpaper: hex("#1B1E4A"), seed: 21) {
        planet(a.minX + 30, a.maxY - 60, 110, magenta)
        text("9:41", font(19, .semibold), white, x: a.minX + 42, y: a.minY + 24, width: 80)
        let m: CGFloat = 24

        // Medium widget: incoming rocket + ETA
        let mw = CGRect(x: a.minX + m, y: a.minY + 88, width: a.width - 2 * m, height: 190)
        fill(mw, panelNavy, radius: 34)
        for i in 0..<3 { seafoam.withAlphaComponent(0.5).setFill(); NSBezierPath(ovalIn: CGRect(x: mw.minX + 34 + CGFloat(i) * 14, y: mw.minY + 140 - CGFloat(i) * 12, width: 8, height: 8)).fill() }
        rocket(CGPoint(x: mw.minX + 100, y: mw.minY + 92), height: 120, hue: seafoam, angle: 40)
        text("INCOMING", font(14, .bold), seafoam, x: mw.minX + 180, y: mw.minY + 34, width: 200, kern: 2)
        text("Maya's package", font(24, .bold), white, x: mw.minX + 180, y: mw.minY + 56, width: 220)
        text("Lands in 4 min", font(18, .medium), textMuted, x: mw.minX + 180, y: mw.minY + 92, width: 220)
        let barW = mw.width - 180 - 28
        fill(CGRect(x: mw.minX + 180, y: mw.minY + 134, width: barW, height: 10), hex("#3A3F7A"), radius: 5)
        fill(CGRect(x: mw.minX + 180, y: mw.minY + 134, width: barW * 0.7, height: 10), seafoam, radius: 5)
        text("Cruise · 70%", font(13, .medium), textMuted, x: mw.minX + 180, y: mw.minY + 152, width: 200)

        // Small widgets
        let sq = (a.width - 2 * m - 22) / 2, sy = mw.maxY + 22
        let s1 = CGRect(x: a.minX + m, y: sy, width: sq, height: sq)
        fill(s1, panelNavy, radius: 34)
        giftBox(CGPoint(x: s1.midX, y: s1.minY + 66), size: 70, hue: gold)
        text("LANDED", font(13, .bold), gold, x: s1.minX, y: s1.minY + 108, width: sq, kern: 2, align: .center)
        text("Grandma Rose", font(18, .bold), white, x: s1.minX, y: s1.minY + 128, width: sq, align: .center)
        text("Tap to open", font(13, .medium), textMuted, x: s1.minX, y: s1.minY + 154, width: sq, align: .center)

        let s2 = CGRect(x: s1.maxX + 22, y: sy, width: sq, height: sq)
        fill(s2, panelNavy, radius: 34)
        let gc = CGPoint(x: s2.midX, y: s2.minY + 78)
        let ringPath = NSBezierPath(ovalIn: CGRect(x: gc.x - 56, y: gc.y - 56, width: 112, height: 112))
        ringPath.setLineDash([5, 6], count: 2, phase: 0); ringPath.lineWidth = 2
        textMuted.withAlphaComponent(0.5).setStroke(); ringPath.stroke()
        planet(gc.x, gc.y, 22, accentBlue)
        planet(gc.x - 40, gc.y - 38, 10, lime); planet(gc.x + 52, gc.y + 16, 10, magenta); planet(gc.x - 30, gc.y + 46, 8, violet)
        text("3 in orbit", font(18, .bold), white, x: s2.minX, y: s2.minY + 140, width: sq, align: .center)
        text("1 rocket in flight", font(13, .medium), textMuted, x: s2.minX, y: s2.minY + 164, width: sq, align: .center)

        // App grid + dock
        let apps: [(String, String, NSColor)] = [("camera.fill", "Camera", hex("#3A3F7A")), ("photo.fill", "Photos", hex("#34487A")),
            ("message.fill", "Messages", hex("#2F6B5A")), ("music.note", "Music", hex("#6A2F5A")),
            ("map.fill", "Maps", hex("#3A5A7A")), ("calendar", "Calendar", hex("#5A3A7A")), ("clock.fill", "Clock", hex("#3A3F7A")), ("", "Orbit", accentBlue)]
        let colW = (a.width - 2 * m) / 4, gy = sy + sq + 34
        for (i, app) in apps.enumerated() {
            let cx = a.minX + m + colW * (CGFloat(i % 4) + 0.5), cy = gy + CGFloat(i / 4) * 104
            let icon = CGRect(x: cx - 31, y: cy, width: 62, height: 62)
            fill(icon, app.2, radius: 15)
            if app.0.isEmpty { rocket(CGPoint(x: icon.midX, y: icon.midY), height: 46, hue: white, angle: 30, mono: true) }
            else { symbol(app.0, icon.insetBy(dx: 17, dy: 17), white.withAlphaComponent(0.9)) }
            text(app.1, font(12, .medium), white, x: cx - 45, y: cy + 68, width: 90, align: .center)
        }
        let dock = CGRect(x: a.minX + 14, y: a.maxY - 118, width: a.width - 28, height: 98)
        fill(dock, white.withAlphaComponent(0.12), radius: 38)
        for (i, name) in ["phone.fill", "safari.fill", "message.fill", "envelope.fill"].enumerated() {
            let cx = dock.minX + dock.width / 4 * (CGFloat(i) + 0.5)
            let icon = CGRect(x: cx - 31, y: dock.midY - 31, width: 62, height: 62)
            fill(icon, hex("#3A3F7A"), radius: 15)
            symbol(name, icon.insetBy(dx: 17, dy: 17), white.withAlphaComponent(0.9))
        }
    }

    // Lock screen
    let b = CGRect(x: 1300, y: 150, width: 452, height: 980)
    phoneFrame(b, wallpaper: hex("#0F1030"), seed: 22) {
        planet(b.maxX - 30, b.maxY - 250, 170, seafoam)
        text("Sunday, September 27", font(20, .semibold), white.withAlphaComponent(0.85), x: b.minX, y: b.minY + 82, width: b.width, align: .center)
        text("9:41", font(112, .heavy), white, x: b.minX, y: b.minY + 100, width: b.width, align: .center)

        // Accessory widgets (vibrant = monochrome)
        let cc = CGPoint(x: b.minX + 92, y: b.minY + 290)
        let track = NSBezierPath(ovalIn: CGRect(x: cc.x - 36, y: cc.y - 36, width: 72, height: 72))
        track.lineWidth = 6; white.withAlphaComponent(0.25).setStroke(); track.stroke()
        let arc = NSBezierPath()
        arc.appendArc(withCenter: cc, radius: 36, startAngle: -90, endAngle: -90 + 360 * 0.7, clockwise: false)
        arc.lineWidth = 6; arc.lineCapStyle = .round; white.setStroke(); arc.stroke()
        rocket(cc, height: 42, hue: white, angle: 0, mono: true)
        let rx = cc.x + 58
        fill(CGRect(x: rx, y: cc.y - 38, width: 250, height: 76), white.withAlphaComponent(0.12), radius: 18)
        text("ORBIT", font(12, .bold), white.withAlphaComponent(0.7), x: rx + 16, y: cc.y - 30, width: 200, kern: 2)
        text("Maya's package", font(18, .bold), white, x: rx + 16, y: cc.y - 13, width: 220)
        text("Lands 9:45 · 70%", font(14, .medium), white.withAlphaComponent(0.8), x: rx + 16, y: cc.y + 10, width: 220)

        // Rich notification with the capsule preview
        let n = CGRect(x: b.minX + 16, y: b.maxY - 330, width: b.width - 32, height: 150)
        fill(n, white.withAlphaComponent(0.92), radius: 30)
        let icon = CGRect(x: n.minX + 18, y: n.minY + 20, width: 42, height: 42)
        fill(icon, accentBlue, radius: 10)
        rocket(CGPoint(x: icon.midX, y: icon.midY), height: 30, hue: white, angle: 30, mono: true)
        text("ORBIT", font(13, .semibold), hex("#6E7191"), x: icon.maxX + 12, y: n.minY + 20, width: 120, kern: 1)
        text("now", font(13, .medium), hex("#6E7191"), x: n.maxX - 160, y: n.minY + 20, width: 44, align: .right)
        text("Capsule landed! 🎁", font(19, .bold), hex("#1A1B3D"), x: icon.maxX + 12, y: n.minY + 42, width: 220)
        text("Maya sent you a package. Tap to unbox.", font(15, .regular), hex("#6E7191"), x: n.minX + 18, y: n.minY + 84, width: n.width - 136, lineSpacing: 2)
        let thumb = CGRect(x: n.maxX - 104, y: n.minY + 16, width: 88, height: 118)
        fill(thumb, hex("#E9D8B8"), radius: 12)
        fill(CGRect(x: thumb.minX + 10, y: thumb.minY + 12, width: 44, height: 50), white, radius: 3)
        fill(CGRect(x: thumb.minX + 14, y: thumb.minY + 16, width: 36, height: 34), magenta.withAlphaComponent(0.8))
        fill(CGRect(x: thumb.minX + 36, y: thumb.minY + 52, width: 44, height: 50), white, radius: 3)
        fill(CGRect(x: thumb.minX + 40, y: thumb.minY + 56, width: 36, height: 34), seafoam.withAlphaComponent(0.85))
        fill(CGRect(x: thumb.minX + 12, y: thumb.minY + 106, width: 64, height: 5), hex("#8A6A45"), radius: 2.5)

        // Flashlight / camera + home bar
        for (i, name) in ["flashlight.on.fill", "camera.fill"].enumerated() {
            let c = CGPoint(x: i == 0 ? b.minX + 70 : b.maxX - 70, y: b.maxY - 80)
            fill(CGRect(x: c.x - 27, y: c.y - 27, width: 54, height: 54), white.withAlphaComponent(0.15), radius: 27)
            symbol(name, CGRect(x: c.x - 12, y: c.y - 12, width: 24, height: 24), white)
        }
        fill(CGRect(x: b.midX - 70, y: b.maxY - 22, width: 140, height: 6), white.withAlphaComponent(0.8), radius: 3)
    }
}
