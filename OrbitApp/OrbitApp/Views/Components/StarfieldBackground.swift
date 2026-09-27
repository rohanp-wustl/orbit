import SwiftUI

/// The living space backdrop for every dark screen: 4-point diamond stars
/// (style sheet §3) at three depths — far ones small and slow, near ones
/// bigger, brighter, and faster — so the scene has parallax depth and
/// always feels like it's drifting through space.
struct StarfieldBackground: View {
    var base: Color = .spaceDeep
    var starCount = 80
    /// Multiplies drift speed — LaunchView cranks this up for warp streaks.
    var speed: Double = 1
    /// 0 = dots, 1 = long warp streaks (for the launch).
    var streak: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(base))
                // A soft glow high on the screen gives the flat navy some depth.
                context.fill(Path(rect), with: .radialGradient(
                    Gradient(colors: [Color.panelNavy.opacity(0.9), .clear]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.12),
                    startRadius: 0, endRadius: size.height * 0.6))

                let time = timeline.date.timeIntervalSinceReferenceDate
                var rng = SeededRandom(seed: 11)
                for _ in 0..<starCount {
                    let x = rng.next() * size.width
                    let startY = rng.next() * size.height
                    let depth = rng.next()            // 0 = far, 1 = near
                    let phase = rng.next() * .pi * 2
                    let tint = rng.next()

                    let drift = time * (3 + depth * 14) * speed
                    let y = (startY + drift).truncatingRemainder(dividingBy: size.height + 20) - 10
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * (0.7 + depth * 2.2) + phase))
                    let radius = 0.8 + depth * 2.4
                    let color: Color = tint > 0.9 ? .orbitGold : (tint > 0.8 ? .skyGlass : .white)

                    if streak > 0.01 {
                        let length = radius * 2 + streak * (20 + depth * 90)
                        let line = Path(roundedRect: CGRect(x: x - radius * 0.4, y: y - length, width: radius * 0.8, height: length),
                                        cornerRadius: radius * 0.4)
                        context.fill(line, with: .color(color.opacity(0.5 + depth * 0.5)))
                    } else {
                        context.fill(Self.diamond(at: CGPoint(x: x, y: y), radius: radius), with: .color(color.opacity(twinkle)))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// 4-point star: long vertical and horizontal points pinched at the waist.
    private static func diamond(at center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let waist = radius * 0.28
        path.move(to: CGPoint(x: center.x, y: center.y - radius * 1.6))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addLine(to: CGPoint(x: center.x + radius * 1.6, y: center.y))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.6))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x - radius * 1.6, y: center.y))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }
}

/// Deterministic pseudo-random numbers, so the star field (and anything
/// else scattered procedurally) is laid out identically on every redraw.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    /// Uniform in 0..<1.
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

#Preview {
    StarfieldBackground()
}
