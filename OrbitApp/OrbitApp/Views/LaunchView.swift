import SwiftUI

/// The send moment, told as a journey. LaunchFlowView has already inserted
/// the row; this view is the show:
/// 1. Loading — the package flies into the ship's cargo hatch.
/// 2. Countdown — 3-2-1 with haptic ticks while the ship rumbles on the pad.
/// 3. Liftoff — smoke, flame, warp-streaking stars.
/// 4. Travel — cut to space: the ship (in the capsule's hue, package in the
///    hatch) flies an arc from your planet to theirs, timed to the real
///    delivery delay, and "Delivered!" lands with confetti.
struct LaunchView: View {
    let capsule: Capsule
    var recipientName: String = "your crew"
    var onFinished: () -> Void

    private enum Phase: Equatable { case loading, countdown(Int), liftoff, travel }

    @State private var phase: Phase = .loading
    @State private var cargoLoaded = false
    @State private var thrust = 0.0
    @State private var rocketLift: CGFloat = 0
    @State private var starSpeed = 1.0
    @State private var starStreak = 0.0
    @State private var smoke = false
    @State private var travelStart = Date()
    @State private var delivered = false
    @State private var confetti = 0
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private var hue: Color { OrbitHue.named(capsule.layout.packageColor).color }
    private var travelSeconds: Double { Double(max(1, capsule.deliveryDelaySeconds)) }

    private var rumbling: Bool {
        switch phase {
        case .countdown, .liftoff: true
        default: false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                StarfieldBackground(speed: starSpeed, streak: starStreak)
                    .animation(.easeIn(duration: 1.2), value: starStreak)

                if phase == .travel {
                    travelScene(size: geo.size)
                        .transition(.opacity)
                } else {
                    padScene(size: geo.size)
                        .transition(.opacity)
                }

                overlayText
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, geo.size.height * 0.12)

                ConfettiBurst(trigger: confetti, origin: .init(x: 0.5, y: 0.35), pieceCount: 110, power: 1.1)
                    .ignoresSafeArea()

                if phase == .travel {
                    Button(delivered ? "Back to launchpad" : "Back to launchpad · track it in Galaxy", action: onFinished)
                        .buttonStyle(OrbitPillButtonStyle())
                        .padding(.horizontal, 28)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: phase)
        .task { await runSequence() }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: phase) { _, new in
            hapticsEnabled && new != .travel
        }
        .sensoryFeedback(.success, trigger: delivered) { _, done in hapticsEnabled && done }
    }

    // MARK: - Pad scene (loading → countdown → liftoff)

    private func padScene(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottom) {
                GantryTower(height: 200)
                    .offset(x: -95)
                Image("launchpad")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                smokePuffs
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !rumbling)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let jitter = rumbling ? CGFloat(sin(t * 70) * 1.8 * thrust) : 0
                    RocketView(height: 230, thrust: thrust, hue: hue, cargo: cargoLoaded ? hue : nil)
                        .offset(x: jitter, y: -rocketLift)
                }
                .padding(.bottom, 260 * 289 / 843 * 0.72 - 230 * RocketView.flameSpace)

                // The package flying in from above and shrinking into the hatch.
                if !cargoLoaded {
                    GiftBoxView(hue: hue, size: 70)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .scale(scale: 0.15).combined(with: .opacity)
                                                    .combined(with: .offset(y: 40))))
                        .padding(.bottom, 330)
                }
            }
            .padding(.bottom, size.height * 0.12)
        }
    }

    // MARK: - Travel scene

    /// Your planet (bottom-left) → their planet (top-right) along an arc.
    private func travelScene(size: CGSize) -> some View {
        let start = CGPoint(x: size.width * 0.2, y: size.height * 0.72)
        let end = CGPoint(x: size.width * 0.78, y: size.height * 0.32)
        let control = CGPoint(x: size.width * 0.18, y: size.height * 0.3)

        return TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let progress = min(1, timeline.date.timeIntervalSince(travelStart) / travelSeconds)
            let point = Self.bezier(start, control, end, progress)
            let tangent = Self.bezierTangent(start, control, end, progress)
            ZStack {
                // The route, dashed.
                Path { path in
                    path.move(to: start)
                    path.addQuadCurve(to: end, control: control)
                }
                .stroke(Color.textOnDarkMuted.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 8]))

                planet(hue: .accentBlue, label: "You", size: 90).position(start)
                planet(hue: OrbitHue.forUser(capsule.recipientId).color, label: recipientName, size: 74).position(end)

                // Trail dots behind the ship.
                ForEach(1..<4) { step in
                    let back = max(0, progress - Double(step) * 0.035)
                    Circle()
                        .fill(Color.cloudGray.opacity(0.7 - Double(step) * 0.15))
                        .frame(width: CGFloat(9 - step * 2), height: CGFloat(9 - step * 2))
                        .position(Self.bezier(start, control, end, back))
                }

                if progress < 1 {
                    RocketView(height: 64, thrust: 0.8, hue: hue, cargo: hue)
                        .rotationEffect(.radians(atan2(tangent.y, tangent.x) + .pi / 2))
                        .position(point)
                } else {
                    GiftBoxView(hue: hue, size: 34)
                        .position(x: end.x + 30, y: end.y + 34)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onChange(of: progress >= 1) { _, arrived in
                if arrived && !delivered {
                    delivered = true
                    confetti += 1
                }
            }
        }
    }

    private func planet(hue: Color, label: String, size: CGFloat) -> some View {
        VStack(spacing: 6) {
            ShadedPlanet(hue: hue, size: size, seed: UInt64(size))
            Text(label)
                .font(.orbitHeading(13))
                .foregroundStyle(Color.textOnDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(SwiftUI.Capsule().fill(Color.spaceDeep.opacity(0.7)))
        }
    }

    static func bezier(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }

    static func bezierTangent(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: 2 * (1 - t) * (c.x - a.x) + 2 * t * (b.x - c.x),
                y: 2 * (1 - t) * (c.y - a.y) + 2 * t * (b.y - c.y))
    }

    // MARK: - Text

    @ViewBuilder
    private var overlayText: some View {
        switch phase {
        case .loading:
            VStack(spacing: 8) {
                Text("Loading cargo")
                    .font(.orbitDisplay(34))
                    .foregroundStyle(Color.textOnDark)
                Text("Packing your capsule into the ship for \(recipientName)")
                    .font(.orbitBody(15))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
        case .countdown(let number):
            VStack(spacing: 8) {
                Text("Launching to \(recipientName)")
                    .font(.orbitHeading(17))
                    .foregroundStyle(Color.textOnDarkMuted)
                Text("\(number)")
                    .font(.orbitDisplay(120))
                    .foregroundStyle(Color.textOnDark)
                    .shadow(color: .accentBlue, radius: 20)
                    .id(number)
                    .transition(.scale(scale: 2).combined(with: .opacity))
            }
        case .liftoff:
            Text("Liftoff!")
                .font(.orbitDisplay(56))
                .foregroundStyle(LinearGradient(colors: [.orbitGold.lightened(by: 0.3), .orbitEmber], startPoint: .top, endPoint: .bottom))
                .shadow(color: .orbitEmber.opacity(0.7), radius: 16)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        case .travel:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(ceil(travelSeconds - context.date.timeIntervalSince(travelStart))))
                VStack(spacing: 6) {
                    Text(delivered ? "Delivered!" : "En route to \(recipientName)")
                        .font(.orbitDisplay(delivered ? 44 : 30))
                        .foregroundStyle(delivered ? Color.orbitSeafoam : Color.textOnDark)
                        .contentTransition(.opacity)
                    Text(delivered ? "It's waiting on \(recipientName)'s launchpad." : "Lands in \(Self.duration(remaining))")
                        .font(.orbitBody(16))
                        .foregroundStyle(Color.textOnDarkMuted)
                        .contentTransition(.numericText(countsDown: true))
                }
                .animation(.spring(duration: 0.5, bounce: 0.4), value: delivered)
            }
        }
    }

    /// "8s", "4m 12s", "2h 05m".
    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(String(format: "%02d", seconds % 60))s" }
        return "\(seconds / 3600)h \(String(format: "%02d", (seconds % 3600) / 60))m"
    }

    /// Puffs that billow out from the pad at ignition.
    private var smokePuffs: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                Circle()
                    .fill(Color.cloudGray.opacity(0.9))
                    .frame(width: 60, height: 60)
                    .scaleEffect(smoke ? 1.6 + CGFloat(index) * 0.15 : 0.2)
                    .offset(x: smoke ? side * CGFloat(40 + index * 18) : 0, y: smoke ? -CGFloat(index * 6) : 0)
                    .opacity(smoke ? 0 : 0.95)
                    .blur(radius: 4)
                    .animation(.easeOut(duration: 1.8).delay(Double(index) * 0.05), value: smoke)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Sequence

    private func runSequence() async {
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.spring(duration: 0.6, bounce: 0.3)) { cargoLoaded = true }
        SoundFX.play(.clunk)
        try? await Task.sleep(for: .seconds(0.8))

        for number in [3, 2, 1] {
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) { phase = .countdown(number) }
            withAnimation(.easeIn(duration: 0.8)) { thrust = [3: 0.2, 2: 0.35, 1: 0.55][number] ?? 0.3 }
            SoundFX.play(.beep)
            try? await Task.sleep(for: .seconds(0.85))
        }
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { phase = .liftoff }
        withAnimation(.easeOut(duration: 0.3)) { thrust = 1 }
        SoundFX.play(.liftoff)
        smoke = true
        starStreak = 1
        withAnimation(.easeIn(duration: 1.6)) {
            rocketLift = 1400
            starSpeed = 14
        }
        try? await Task.sleep(for: .seconds(1.7))
        withAnimation(.easeOut(duration: 1)) {
            starSpeed = 1
            starStreak = 0
        }
        // The capsule's clock started at launch, so the trip picks up where it really is.
        travelStart = capsule.launchedAt ?? Date()
        phase = .travel
    }
}

/// The launchpad's gantry tower (style sheet §5 Home): a panelNavy truss
/// with cross-bracing and a service arm reaching toward the ship.
struct GantryTower: View {
    var height: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let railWidth = w * 0.12
            let color = Color.panelNavy.lightened(by: 0.12)
            // Two rails.
            context.fill(Path(CGRect(x: w * 0.1, y: h * 0.08, width: railWidth, height: h * 0.92)), with: .color(color))
            context.fill(Path(CGRect(x: w * 0.55, y: h * 0.08, width: railWidth, height: h * 0.92)), with: .color(color.darkened(by: 0.15)))
            // Cross-bracing.
            var brace = Path()
            let steps = 6
            for index in 0..<steps {
                let y0 = h * 0.08 + CGFloat(index) * (h * 0.92 / CGFloat(steps))
                let y1 = y0 + h * 0.92 / CGFloat(steps)
                brace.move(to: CGPoint(x: w * 0.16, y: y0))
                brace.addLine(to: CGPoint(x: w * 0.61, y: y1))
                brace.move(to: CGPoint(x: w * 0.61, y: y0))
                brace.addLine(to: CGPoint(x: w * 0.16, y: y1))
            }
            context.stroke(brace, with: .color(color.opacity(0.8)), lineWidth: 2)
            // Service arm + beacon.
            context.fill(Path(roundedRect: CGRect(x: w * 0.55, y: h * 0.3, width: w * 0.45, height: railWidth * 0.8), cornerRadius: 2),
                         with: .color(color))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.12, y: 0, width: w * 0.16, height: w * 0.16)), with: .color(.orbitGold))
        }
        .frame(width: height * 0.32, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    LaunchView(capsule: Capsule(senderId: UUID(), recipientId: UUID(), crewLinkId: UUID(),
                                layout: CapsuleLayout(background: "night_sky", template: "polaroid_scatter", items: [], packageColor: "seafoam"),
                                launchedAt: Date()),
               recipientName: "Maya", onFinished: {})
}
