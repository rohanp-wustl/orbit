import SwiftUI

/// A one-shot confetti burst: flat rounded pieces (matching the
/// confetti_large/small art) blasted outward from `origin`, then tumbling
/// down under gravity. Bump `trigger` to fire again.
struct ConfettiBurst: View {
    var trigger: Int
    /// Burst center as a fraction of the view.
    var origin: UnitPoint = .center
    var pieceCount = 90
    var power: CGFloat = 1

    @State private var startDate: Date?

    private static let palette: [Color] = [.orbitMagenta, .orbitGold, .orbitSeafoam, .skyGlass, .orbitEmber, .orbitViolet, .orbitLime]
    private static let duration: Double = 2.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let t = timeline.date.timeIntervalSince(startDate)
                guard t < Self.duration else { return }
                let o = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
                var rng = SeededRandom(seed: UInt64(trigger) &+ 99)
                for _ in 0..<pieceCount {
                    let angle = rng.next() * .pi * 2
                    let speed = (220 + rng.next() * 520) * power
                    let spin = (rng.next() - 0.5) * 16
                    let color = Self.palette[Int(rng.next() * Double(Self.palette.count)) % Self.palette.count]
                    let isDot = rng.next() > 0.65
                    let drag = 1.6
                    // Velocity decays with drag; gravity pulls pieces back down.
                    let travel = (1 - exp(-drag * t)) / drag
                    let x = o.x + cos(angle) * speed * travel
                    let y = o.y + sin(angle) * speed * travel + 380 * t * t
                    let fade = max(0, 1 - pow(t / Self.duration, 3))
                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(angle + spin * t))
                    // Tumbling: pieces flip edge-on and back as they fall.
                    let flip = abs(cos(t * (3 + spin)))
                    let rect = isDot
                        ? CGRect(x: -3.5, y: -3.5, width: 7, height: 7)
                        : CGRect(x: -9, y: -3 * flip, width: 18, height: max(1.5, 6 * flip))
                    piece.fill(Path(roundedRect: rect, cornerRadius: 3.5), with: .color(color.opacity(fade)))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in startDate = Date() }
        .onAppear { if trigger > 0 { startDate = Date() } }
        .accessibilityHidden(true)
    }
}

/// The primary action button: a chunky pill that sits on a darker "base"
/// and physically presses down into it — the tactile, game-like button
/// feel — with a haptic on press.
struct OrbitPillButtonStyle: ButtonStyle {
    var color: Color = .accentBlue
    var textColor: Color = .textOnDark
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        let depth: CGFloat = configuration.isPressed ? 1 : 5
        configuration.label
            .font(.orbitHeading(17))
            .foregroundStyle(textColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                SwiftUI.Capsule()
                    .fill(LinearGradient(colors: [color.lightened(by: 0.18), color], startPoint: .top, endPoint: .bottom))
                    .overlay(SwiftUI.Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1).padding(1))
            )
            .background(SwiftUI.Capsule().fill(color.darkened(by: 0.35)).offset(y: depth))
            .offset(y: 5 - depth)
            .shadow(color: color.opacity(0.45), radius: configuration.isPressed ? 6 : 14, y: 6)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in
                pressed && UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
            }
    }
}

/// Soft raised panel for dark screens: a subtle top highlight and inner
/// edge light so cards read as physical objects floating over space.
struct OrbitCard: ViewModifier {
    var fill: Color = .panelNavy
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [fill.lightened(by: 0.07), fill], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.02)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            )
    }
}

extension View {
    func orbitCard(fill: Color = .panelNavy, cornerRadius: CGFloat = 24) -> some View {
        modifier(OrbitCard(fill: fill, cornerRadius: cornerRadius))
    }
}

/// Level badge + XP progress bar. The fill animates and shimmers when XP
/// is gained.
struct XPBar: View {
    let progress: PilotProgress

    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.orbitGold.lightened(by: 0.3), .orbitGold, .orbitGold.darkened(by: 0.25)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 26))
                    .shadow(color: .orbitGold.opacity(0.6), radius: 8)
                Text("\(progress.level)")
                    .font(.orbitDisplay(20))
                    .foregroundStyle(Color.spaceDeep)
                    .contentTransition(.numericText())
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(progress.rank)
                        .font(.orbitHeading(15))
                        .foregroundStyle(Color.textOnDark)
                    Spacer()
                    Text("\(progress.xpToNextLevel) XP to level \(progress.level + 1)")
                        .font(.orbitBody(12))
                        .foregroundStyle(Color.textOnDarkMuted)
                        .contentTransition(.numericText())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        SwiftUI.Capsule().fill(Color.spaceDeep)
                        SwiftUI.Capsule()
                            .fill(LinearGradient(colors: [.orbitSeafoam, .skyGlass, .accentBlue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(10, geo.size.width * progress.levelProgress))
                            .overlay(alignment: .leading) {
                                // A moving glint across the fill.
                                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 40)
                                    .offset(x: shimmer ? geo.size.width : -40)
                            }
                            .clipShape(SwiftUI.Capsule())
                    }
                }
                .frame(height: 10)
            }
        }
        .animation(.spring(duration: 0.8, bounce: 0.3), value: progress)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(1)) { shimmer = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(progress.level) \(progress.rank), \(progress.xpToNextLevel) XP to next level")
    }
}

/// The "+50 XP" pop-in after launching, unboxing, or adding crew — with a
/// full-screen confetti burst and a bigger banner on level-up.
struct RewardToast: View {
    let reward: Reward
    var onDone: () -> Void

    @State private var shown = false
    @State private var confetti = 0

    var body: some View {
        ZStack {
            ConfettiBurst(trigger: confetti, origin: .init(x: 0.5, y: 0.2), pieceCount: reward.newLevel == nil ? 60 : 140,
                          power: reward.newLevel == nil ? 0.8 : 1.3)
                .ignoresSafeArea()

            VStack(spacing: 6) {
                if let newLevel = reward.newLevel {
                    Text("LEVEL UP!")
                        .font(.orbitDisplay(30))
                        .foregroundStyle(LinearGradient(colors: [.orbitGold.lightened(by: 0.3), .orbitGold], startPoint: .top, endPoint: .bottom))
                    Text("You reached level \(newLevel)")
                        .font(.orbitBody(14))
                        .foregroundStyle(Color.textOnDark)
                }
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.orbitGold)
                        .symbolEffect(.bounce, value: shown)
                    Text("+\(reward.xp) XP")
                        .font(.orbitDisplay(22))
                        .foregroundStyle(Color.orbitGold)
                    Text(reward.message)
                        .font(.orbitHeading(15))
                        .foregroundStyle(Color.textOnDark)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .orbitCard(fill: .panelNavy, cornerRadius: 22)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -40)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
        }
        .allowsHitTesting(false)
        .sensoryFeedback(.success, trigger: shown) { _, isShown in
            isShown && UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        }
        .task(id: reward.id) {
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) { shown = true }
            confetti += 1
            try? await Task.sleep(for: .seconds(reward.newLevel == nil ? 2.2 : 3.2))
            withAnimation(.easeIn(duration: 0.3)) { shown = false }
            try? await Task.sleep(for: .seconds(0.35))
            onDone()
        }
    }
}

#Preview {
    ZStack {
        StarfieldBackground()
        VStack(spacing: 30) {
            XPBar(progress: PilotProgress(launched: 3, unboxed: 2, crewCount: 1))
                .padding()
                .orbitCard()
            Button("Send a package") {}
                .buttonStyle(OrbitPillButtonStyle())
        }
        .padding()
        RewardToast(reward: Reward(xp: 50, message: "Capsule launched!", newLevel: 2), onDone: {})
    }
}
