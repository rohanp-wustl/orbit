import SwiftUI

/// The capsule ship, built to the style sheet's rocket construction (§3):
/// two-tone hullCap nose cone, a two-tone body in the capsule's recolor
/// hue, swept cloudGray fins, a sky-glass window with a hullCap ring, a
/// hullCap engine collar, and a nested ember/gold flame. Drawn in code (the
/// original rocket art was one fixed blue) so every capsule's ship flies in
/// the same color as its package. Carries the v6 depth shading.
struct RocketView: View {
    var height: CGFloat
    /// 0 = engines off, ~0.4 = idling/hovering, 1 = full launch burn.
    var thrust: Double = 0
    /// Body color. Defaults to the blue of Design's original rocket art.
    var hue: Color = Color(hex: "#4696D9")
    /// Shows the capsule's package through a cargo hatch below the window.
    var cargo: Color? = nil

    private static let aspect: CGFloat = 0.58
    /// Fraction of the frame below the engine collar, reserved for the
    /// flame. A parked ship is pulled down by this much to sit on a pad.
    static let flameSpace: CGFloat = 0.2

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size, flicker: 1)
        }
        .overlay {
            if thrust > 0.01 {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    // Two out-of-phase sines = an organic, non-repeating flicker.
                    let flicker = 1 + 0.12 * sin(time * 31) + 0.07 * sin(time * 17 + 1.3)
                    Canvas { context, size in
                        drawFlame(in: &context, size: size, flicker: flicker)
                    }
                    .shadow(color: .orbitGold.opacity(0.8 * thrust), radius: 16 * thrust, y: height * 0.1)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: height * Self.aspect, height: height)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, flicker: Double) {
        let h = size.height
        let cx = size.width / 2
        let bodyWidth = h * 0.3
        let left = cx - bodyWidth / 2
        let right = cx + bodyWidth / 2
        let noseBase = h * 0.24
        let bodyBottom = h * 0.74
        let collarBottom = h * (1 - Self.flameSpace)

        // Fins (behind the body): swept back and angled outward.
        for side in [-1.0, 1.0] {
            var fin = Path()
            let root = side < 0 ? left : right
            fin.move(to: CGPoint(x: root, y: h * 0.52))
            fin.addQuadCurve(to: CGPoint(x: root + side * h * 0.13, y: h * 0.74),
                             control: CGPoint(x: root + side * h * 0.12, y: h * 0.58))
            fin.addQuadCurve(to: CGPoint(x: root + side * h * 0.1, y: h * 0.8),
                             control: CGPoint(x: root + side * h * 0.14, y: h * 0.8))
            fin.addLine(to: CGPoint(x: root, y: h * 0.73))
            fin.closeSubpath()
            context.fill(fin, with: .linearGradient(
                Gradient(colors: [Color.cloudGray.lightened(by: 0.25), .cloudGray, Color.cloudGray.darkened(by: 0.2)]),
                startPoint: CGPoint(x: root, y: h * 0.48), endPoint: CGPoint(x: root + side * h * 0.15, y: h * 0.8)))
        }

        // Hull silhouette: rounded cone flowing into a straight cylinder.
        var hull = Path()
        hull.move(to: CGPoint(x: cx, y: 0))
        hull.addCurve(to: CGPoint(x: right, y: noseBase + h * 0.04),
                      control1: CGPoint(x: cx + bodyWidth * 0.28, y: h * 0.02),
                      control2: CGPoint(x: right, y: h * 0.12))
        hull.addLine(to: CGPoint(x: right, y: bodyBottom - bodyWidth * 0.18))
        hull.addQuadCurve(to: CGPoint(x: right - bodyWidth * 0.18, y: bodyBottom), control: CGPoint(x: right, y: bodyBottom))
        hull.addLine(to: CGPoint(x: left + bodyWidth * 0.18, y: bodyBottom))
        hull.addQuadCurve(to: CGPoint(x: left, y: bodyBottom - bodyWidth * 0.18), control: CGPoint(x: left, y: bodyBottom))
        hull.addLine(to: CGPoint(x: left, y: noseBase + h * 0.04))
        hull.addCurve(to: CGPoint(x: cx, y: 0),
                      control1: CGPoint(x: left, y: h * 0.12),
                      control2: CGPoint(x: cx - bodyWidth * 0.28, y: h * 0.02))
        hull.closeSubpath()

        context.drawLayer { layer in
            layer.clip(to: hull)
            // Body: two-tone vertical split (lighter tint left / base right)
            // with falloff toward the edges for roundness.
            layer.fill(Path(CGRect(x: left, y: 0, width: bodyWidth / 2, height: h)),
                       with: .linearGradient(Gradient(colors: [hue.lightened(by: 0.35), hue.lightened(by: 0.5)]),
                                             startPoint: CGPoint(x: left, y: 0), endPoint: CGPoint(x: cx, y: 0)))
            layer.fill(Path(CGRect(x: cx, y: 0, width: bodyWidth / 2, height: h)),
                       with: .linearGradient(Gradient(colors: [hue, hue.darkened(by: 0.22)]),
                                             startPoint: CGPoint(x: cx, y: 0), endPoint: CGPoint(x: right, y: 0)))
            // Nose cone: fixed hullCapLight / hullCap split, not recolored.
            layer.fill(Path(CGRect(x: left, y: 0, width: bodyWidth / 2, height: noseBase)), with: .color(.hullCapLight))
            layer.fill(Path(CGRect(x: cx, y: 0, width: bodyWidth / 2, height: noseBase)), with: .color(.hullCap))
            // Specular stripe down the lit side.
            layer.fill(Path(roundedRect: CGRect(x: left + bodyWidth * 0.12, y: noseBase + h * 0.03,
                                                width: bodyWidth * 0.08, height: bodyBottom - noseBase - h * 0.08),
                            cornerRadius: bodyWidth * 0.04),
                       with: .color(.white.opacity(0.35)))
        }

        // Window: hullCap ring, two-tone sky glass (lighter top-left).
        let windowRadius = bodyWidth * 0.3
        let windowCenter = CGPoint(x: cx, y: h * 0.38)
        let ring = CGRect(x: windowCenter.x - windowRadius, y: windowCenter.y - windowRadius,
                          width: windowRadius * 2, height: windowRadius * 2)
        context.fill(Path(ellipseIn: ring), with: .color(.hullCap))
        let glass = ring.insetBy(dx: windowRadius * 0.22, dy: windowRadius * 0.22)
        context.fill(Path(ellipseIn: glass), with: .color(.skyGlass))
        var glassHighlight = Path()
        glassHighlight.addArc(center: windowCenter, radius: glass.width / 2,
                              startAngle: .degrees(135), endAngle: .degrees(315), clockwise: false)
        glassHighlight.closeSubpath()
        context.fill(glassHighlight, with: .color(Color.skyGlass.lightened(by: 0.45)))

        // Cargo hatch: the capsule's package riding inside, visible through a porthole.
        if let cargo {
            let hatch = CGRect(x: cx - bodyWidth * 0.26, y: h * 0.52, width: bodyWidth * 0.52, height: bodyWidth * 0.44)
            context.fill(Path(roundedRect: hatch, cornerRadius: bodyWidth * 0.1), with: .color(.hullCap))
            let box = hatch.insetBy(dx: bodyWidth * 0.07, dy: bodyWidth * 0.07)
            context.fill(Path(roundedRect: box, cornerRadius: bodyWidth * 0.05),
                         with: .linearGradient(Gradient(colors: [cargo.lightened(by: 0.2), cargo.darkened(by: 0.1)]),
                                               startPoint: CGPoint(x: box.minX, y: box.minY), endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            context.fill(Path(CGRect(x: box.midX - box.width * 0.1, y: box.minY, width: box.width * 0.2, height: box.height)),
                         with: .color(.white.opacity(0.9)))
        }

        // Engine collar where the fins meet the body.
        let collar = CGRect(x: cx - bodyWidth * 0.38, y: bodyBottom - h * 0.01, width: bodyWidth * 0.76, height: collarBottom - bodyBottom + h * 0.01)
        context.fill(Path(roundedRect: collar, cornerRadius: bodyWidth * 0.06),
                     with: .linearGradient(Gradient(colors: [Color.hullCapLight, .hullCap]),
                                           startPoint: CGPoint(x: collar.minX, y: 0), endPoint: CGPoint(x: collar.maxX, y: 0)))
    }

    /// Two nested tapering flames, point down: ember outside, gold inside.
    private func drawFlame(in context: inout GraphicsContext, size: CGSize, flicker: Double) {
        let h = size.height
        let cx = size.width / 2
        let top = h * (1 - Self.flameSpace)
        let length = h * Self.flameSpace * (0.45 + 0.9 * thrust) * flicker
        func flame(width: CGFloat, length: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: cx - width / 2, y: top))
            path.addQuadCurve(to: CGPoint(x: cx, y: top + length), control: CGPoint(x: cx - width * 0.55, y: top + length * 0.55))
            path.addQuadCurve(to: CGPoint(x: cx + width / 2, y: top), control: CGPoint(x: cx + width * 0.55, y: top + length * 0.55))
            path.closeSubpath()
            return path
        }
        let bodyWidth = h * 0.3
        context.fill(flame(width: bodyWidth * 0.7, length: length), with: .color(.orbitEmber))
        context.fill(flame(width: bodyWidth * 0.4, length: length * 0.68), with: .color(.orbitGold))
    }
}

/// Cosmo the mascot (Assets.xcassets/cosmo_wave) with the style sheet's four
/// poses (§6). Only the wave art exists so far, so each pose is expressed
/// through motion and props on the same art until Design draws the rest:
/// wave (greetings), pack (loading — leaning in with a package), sleep
/// (empty states — dozing with z's), cheer (celebrations — jumping).
struct CosmoView: View {
    enum Pose { case wave, pack, sleep, cheer }

    var size: CGFloat
    var message: String? = nil
    var floating = true
    var pose: Pose = .wave

    @State private var bob = false

    private var tilt: Double {
        switch pose {
        case .wave: bob ? 4 : -4
        case .pack: bob ? 16 : 10
        case .sleep: bob ? -8 : -10
        case .cheer: bob ? 6 : -6
        }
    }

    private var lift: CGFloat {
        switch pose {
        case .cheer: bob ? -size * 0.22 : 0
        case .sleep: bob ? -size * 0.02 : 0
        default: bob ? -size * 0.06 : size * 0.04
        }
    }

    private var bobAnimation: Animation {
        switch pose {
        case .cheer: .spring(duration: 0.45, bounce: 0.5).repeatForever(autoreverses: true)
        case .sleep: .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
        default: .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            if let message {
                Text(message)
                    .font(.orbitHeading(15))
                    .foregroundStyle(Color.textOnLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        SpeechBubble()
                            .fill(Color.cardWhite)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    )
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
            Image("cosmo_wave")
                .resizable()
                .scaledToFit()
                .frame(height: size)
                .saturation(pose == .sleep ? 0.7 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if pose == .pack {
                        GiftBoxView(hue: .orbitMagenta, size: size * 0.32, showsShadow: false)
                            .offset(x: size * 0.12, y: size * 0.04)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if pose == .sleep {
                        Text("z z")
                            .font(.system(size: size * 0.16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.textOnDarkMuted)
                            .offset(x: size * 0.2, y: bob ? -size * 0.2 : -size * 0.05)
                            .opacity(bob ? 0.3 : 1)
                    }
                }
                .rotationEffect(.degrees(tilt), anchor: .bottom)
                .offset(y: lift)
                .shadow(color: .skyGlass.opacity(0.35), radius: size * 0.15)
        }
        .onAppear {
            guard floating else { return }
            withAnimation(bobAnimation) { bob = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.map { "Cosmo says: \($0)" } ?? "Cosmo")
    }
}

/// Rounded bubble with a little tail pointing down at the speaker.
struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 9
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: min(18, body.height / 2), style: .continuous)
        path.move(to: CGPoint(x: rect.midX - tail, y: body.maxY - 1))
        path.addLine(to: CGPoint(x: rect.midX, y: body.maxY + tail))
        path.addLine(to: CGPoint(x: rect.midX + tail, y: body.maxY - 1))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        StarfieldBackground()
        HStack(spacing: 24) {
            RocketView(height: 200)
            RocketView(height: 200, hue: .orbitMagenta, cargo: .orbitMagenta)
            RocketView(height: 200, thrust: 1, hue: .orbitSeafoam)
        }
        .offset(y: -140)
        CosmoView(size: 130, message: "Let's send your first package!")
            .offset(y: 200)
    }
}
