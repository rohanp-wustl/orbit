import SwiftUI

/// A planet with real volume: lit from the top-left, a soft terminator
/// shadow, specular highlight and rim light, and surface spots that rotate
/// around the sphere (foreshortening as they turn toward the edge) so it
/// reads as a spinning 3D ball, not a flat disc. Optional tilted ring that
/// passes behind and in front of the body.
struct ShadedPlanet: View {
    enum Surface { case smooth, banded, cratered }

    let hue: Color
    var size: CGFloat
    var surface: Surface = .cratered
    var ringed = false
    /// Radians per second of spin; 0 renders once and stays still.
    var spinSpeed: Double = 0.35
    var glow = true
    /// Varies the spot layout between planets of the same hue.
    var seed: UInt64 = 1

    var body: some View {
        ZStack {
            if ringed { ring.mask(halfMask(top: true)).rotationEffect(.degrees(-16)) }
            sphere.frame(width: size, height: size)
            if ringed { ring.mask(halfMask(top: false)).rotationEffect(.degrees(-16)) }
        }
        .frame(width: ringed ? size * 1.8 : size, height: size)
        .shadow(color: glow ? hue.opacity(0.55) : .clear, radius: size * 0.22)
        .accessibilityHidden(true)
    }

    private var sphere: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: spinSpeed == 0)) { timeline in
            Canvas { context, canvasSize in
                let r = min(canvasSize.width, canvasSize.height) / 2
                let c = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                let time = spinSpeed == 0 ? 0 : timeline.date.timeIntervalSinceReferenceDate

                // Base: radial light falloff from the top-left light source.
                context.fill(disc, with: .radialGradient(
                    Gradient(colors: [hue.lightened(by: 0.35), hue, hue.darkened(by: 0.3)]),
                    center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.6))

                context.clip(to: disc)
                drawSurface(in: &context, center: c, radius: r, time: time)

                // Terminator: the far side falls into shadow.
                context.fill(disc, with: .linearGradient(
                    Gradient(stops: [.init(color: .clear, location: 0.42), .init(color: .black.opacity(0.5), location: 1)]),
                    startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)))
                // Specular highlight.
                context.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.66, y: c.y - r * 0.72, width: r * 0.62, height: r * 0.42)),
                             with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .clear]),
                                                   center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.52),
                                                   startRadius: 0, endRadius: r * 0.34))
                // Rim light along the lit edge.
                context.stroke(disc, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.35), .clear]),
                    startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: c), lineWidth: r * 0.06)
            }
        }
    }

    private func drawSurface(in context: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, time: Double) {
        var rng = SeededRandom(seed: seed)
        switch surface {
        case .smooth:
            break
        case .banded:
            // Bands follow latitude, so they stay put while the planet spins
            // — only their wobble shifts, which keeps them from looking pasted on.
            for index in 0..<4 {
                let lat = -0.6 + Double(index) * 0.4 + rng.next() * 0.08
                let y = c.y + r * sin(lat)
                let thickness = r * (0.1 + rng.next() * 0.1)
                let wobble = sin(time * 0.8 + Double(index)) * r * 0.02
                context.fill(Path(roundedRect: CGRect(x: c.x - r, y: y - thickness / 2 + wobble, width: r * 2, height: thickness),
                                  cornerRadius: thickness / 2),
                             with: .color(hue.darkened(by: 0.2).opacity(0.75)))
            }
        case .cratered:
            for _ in 0..<10 {
                let lon = rng.next() * .pi * 2
                let lat = (rng.next() - 0.5) * 1.5
                let spotRadius = r * (0.07 + rng.next() * 0.13)
                let angle = lon + time * spinSpeed
                let facing = cos(angle)               // 1 = facing us, 0 = at the edge
                guard facing > 0.05 else { continue } // on the far side
                let x = c.x + r * cos(lat) * sin(angle)
                let y = c.y + r * sin(lat)
                let rect = CGRect(x: x - spotRadius * facing, y: y - spotRadius * cos(lat),
                                  width: spotRadius * 2 * facing, height: spotRadius * 2 * cos(lat))
                context.fill(Path(ellipseIn: rect), with: .color(hue.darkened(by: 0.25).opacity(0.85)))
                // Lit lower rim makes each crater read as a dent.
                context.stroke(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08).offsetBy(dx: 0, dy: rect.height * 0.08)),
                               with: .color(hue.lightened(by: 0.25).opacity(0.5)), lineWidth: max(0.6, spotRadius * 0.12))
            }
        }
    }

    private var ring: some View {
        // strokeBorder keeps the stroke inside the frame, so the half masks
        // don't clip flat notches into the ring's ends.
        Ellipse()
            .strokeBorder(LinearGradient(colors: [hue.lightened(by: 0.6), hue.lightened(by: 0.25), hue.darkened(by: 0.15)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: size * 0.075)
            .frame(width: size * 1.75, height: size * 0.46)
    }

    /// Top half hides behind the body, bottom half passes in front.
    private func halfMask(top: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle().opacity(top ? 1 : 0)
            Rectangle().opacity(top ? 0 : 1)
        }
    }
}

#Preview {
    ZStack {
        Color.spaceDeep.ignoresSafeArea()
        VStack(spacing: 40) {
            ShadedPlanet(hue: .accentBlue, size: 140)
            HStack(spacing: 30) {
                ShadedPlanet(hue: .orbitMagenta, size: 70, surface: .banded, ringed: true)
                ShadedPlanet(hue: .orbitSeafoam, size: 60, surface: .smooth)
                ShadedPlanet(hue: .orbitGold, size: 60, seed: 4)
            }
        }
    }
}
