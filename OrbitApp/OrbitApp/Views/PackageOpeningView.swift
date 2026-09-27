import SwiftUI

/// The recipient's unboxing (style sheet §5 "Package opening"):
/// in transit (descending rocket + countdown) → waiting (package wobbles,
/// "Tap to open") → shake (1–2s, building haptics) → burst (lid flies off,
/// confetti, "Capsule landed!") → reveal (white card slides up, scrapbook
/// items surface one at a time).
struct PackageOpeningView: View {
    let capsule: Capsule
    let senderName: String
    /// Called once, when leaving after the reveal — marks it opened + reward.
    var onOpened: () -> Void
    var onClose: () -> Void
    /// "Send one back": opens Create with the sender preselected.
    var onReply: (() -> Void)? = nil

    private enum Phase { case inTransit, waiting, shaking, burst, reveal }

    @State private var phase: Phase
    @State private var lid: CGFloat = 0
    @State private var focus = false
    @State private var burstArt = false
    @State private var confetti = 0
    @State private var shakeTrigger = 0
    @State private var hapticTick = 0
    @State private var revealedCount = 0
    @State private var didReveal = false
    // Landing sequence (only when opened while the ship is still en route).
    @State private var shipDown = false
    @State private var shipHasCargo = true
    @State private var shipGone = false
    @State private var cardDrag: CGFloat = 0
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    init(capsule: Capsule, senderName: String, onOpened: @escaping () -> Void, onClose: @escaping () -> Void,
         onReply: (() -> Void)? = nil) {
        self.capsule = capsule
        self.senderName = senderName
        self.onOpened = onOpened
        self.onClose = onClose
        self.onReply = onReply
        let stillFlying = (capsule.deliveryAt ?? .distantPast) > .now && capsule.status != .landed
        _phase = State(initialValue: stillFlying ? .inTransit : .waiting)
    }

    private var hue: Color { OrbitHue.named(capsule.layout.packageColor).color }
    private var orderedItems: [LayoutItem] { capsule.layout.items.sorted { $0.z < $1.z } }
    private var isFullyRevealed: Bool { revealedCount >= orderedItems.count }

    var body: some View {
        ZStack {
            StarfieldBackground()
            Color.black.opacity(phase == .reveal ? 0.45 : (focus ? 0.25 : 0))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: focus)

            headline
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 90)

            centerpiece
                .offset(y: phase == .reveal ? -220 : 0)
                .scaleEffect(phase == .reveal ? 0.6 : 1)
                .animation(.spring(duration: 0.7, bounce: 0.3), value: phase)

            ConfettiBurst(trigger: confetti, origin: .init(x: 0.5, y: 0.45), pieceCount: 130, power: 1.2)
                .ignoresSafeArea()

            footer
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 80)

            if phase == .reveal {
                revealCard
                    .transition(.move(edge: .bottom))
            }

            closeButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 20)
                .padding(.top, 8)
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.8), trigger: hapticTick) { _, _ in hapticsEnabled }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: confetti) { _, _ in hapticsEnabled }
        .task { await waitForLanding() }
    }

    // MARK: - Pieces

    private var headline: some View {
        VStack(spacing: 8) {
            switch phase {
            case .burst:
                Text("Capsule landed!")
                    .font(.orbitDisplay(36))
                    .foregroundStyle(Color.orbitSeafoam)
                    .shadow(color: .orbitSeafoam.opacity(0.6), radius: 14)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .reveal:
                EmptyView()
            default:
                Text("\(senderName) sent you a capsule")
                    .font(.orbitDisplay(26))
                    .foregroundStyle(Color.textOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.5), value: phase)
    }

    @ViewBuilder
    private var centerpiece: some View {
        if phase == .inTransit {
            // The capsule's ship, hovering on approach with the package in its hatch.
            ZStack {
                RocketView(height: 190, thrust: shipDown ? 0.95 : 0.6, hue: hue, cargo: shipHasCargo ? hue : nil)
                    .offset(y: shipDown ? 0 : -140)
                    .offset(y: shipGone ? -1000 : 0)
                    .phaseAnimator(shipDown ? [0.0] : [0.0, 10, 0]) { view, bob in
                        view.offset(y: bob)
                    } animation: { _ in .easeInOut(duration: 1) }
                if !shipHasCargo {
                    // Package ejected from the hatch, bouncing down beside the ship.
                    GiftBoxView(hue: hue, size: 150)
                        .transition(.scale(scale: 0.1, anchor: .top).combined(with: .offset(y: -60)))
                        .offset(y: 60)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            ZStack {
                Image("confetti_large")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .scaleEffect(burstArt ? 1.4 : 0.2)
                    .opacity(burstArt ? 0 : (phase == .burst ? 1 : 0))
                    .animation(.easeOut(duration: 1.1), value: burstArt)

                GiftBoxView(hue: hue, size: 150, lidProgress: lid)
                    .scaleEffect(focus ? 1.2 : 1)
                    // Idle wobble while waiting to be tapped.
                    .phaseAnimator(phase == .waiting ? [0.0, -7, 7, -4, 4, 0, 0, 0, 0] : [0.0]) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } animation: { _ in .easeInOut(duration: 0.12) }
                    // The build-up shake: faster and wider until it pops.
                    .keyframeAnimator(initialValue: 0.0, trigger: shakeTrigger) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(4, duration: 0.07)
                            LinearKeyframe(-4, duration: 0.07)
                            LinearKeyframe(7, duration: 0.07)
                            LinearKeyframe(-7, duration: 0.07)
                            LinearKeyframe(10, duration: 0.07)
                            LinearKeyframe(-10, duration: 0.07)
                            LinearKeyframe(13, duration: 0.07)
                            LinearKeyframe(-13, duration: 0.07)
                            LinearKeyframe(16, duration: 0.07)
                            LinearKeyframe(-16, duration: 0.07)
                            LinearKeyframe(0, duration: 0.06)
                        }
                    }
                    .onTapGesture { if phase == .waiting { Task { await open() } } }
                    .accessibilityLabel("Package from \(senderName)")
                    .accessibilityHint("Tap to open")
                    .accessibilityAddTraits(.isButton)
            }
            .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .inTransit:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int((capsule.deliveryAt ?? context.date).timeIntervalSince(context.date).rounded(.up)))
                VStack(spacing: 6) {
                    Text("Still in orbit")
                        .font(.orbitHeading(17))
                        .foregroundStyle(Color.textOnDark)
                    Text("Landing in \(seconds)s")
                        .font(.orbitBody(15))
                        .foregroundStyle(Color.textOnDarkMuted)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
        case .waiting:
            Text("Tap to open")
                .font(.orbitHeading(18))
                .foregroundStyle(Color.textOnDark)
                .phaseAnimator([1.0, 0.45]) { view, opacity in
                    view.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.9) }
        default:
            EmptyView()
        }
    }

    /// The letter sheet from the mockup: a white card that takes over the
    /// bottom of the screen with the scrapbook page inside.
    private var revealCard: some View {
        VStack(spacing: 14) {
            SwiftUI.Capsule()
                .fill(Color.dividerLight)
                .frame(width: 40, height: 5)
            HStack(spacing: 6) {
                Text("From \(senderName)")
                    .font(.orbitHeading(16))
                    .foregroundStyle(Color.textOnLight)
                Text("· \(capsule.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.orbitBody(14))
                    .foregroundStyle(Color.textOnLightMuted)
                Spacer()
            }
            CapsulePageView(layout: capsule.layout, senderId: capsule.senderId,
                            visibleItemIds: Set(orderedItems.prefix(revealedCount).map(\.id)))
                .animation(.spring(duration: 0.5, bounce: 0.4), value: revealedCount)
                .onTapGesture { revealAll() }
            Button(isFullyRevealed ? "Done" : "Reveal all") {
                if isFullyRevealed { finish() } else { revealAll() }
            }
            .buttonStyle(OrbitPillButtonStyle())
            if isFullyRevealed, let onReply {
                Button {
                    onOpened()
                    onReply()
                } label: {
                    Label("Send \(senderName) one back", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.orbitHeading(15))
                        .foregroundStyle(Color.accentBlue)
                }
            }
        }
        .padding(20)
        .padding(.bottom, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34)
                .fill(Color.cardWhite)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.35), radius: 20, y: -6)
        )
        .offset(y: max(0, cardDrag))
        // Style sheet §5: exit via close button or swipe-down.
        .gesture(
            DragGesture()
                .onChanged { value in cardDrag = value.translation.height }
                .onEnded { value in
                    if value.translation.height > 140 { finish() }
                    else { withAnimation(.spring) { cardDrag = 0 } }
                }
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var closeButton: some View {
        Button {
            finish()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textOnDark)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.panelNavy.opacity(0.9)))
        }
        .opacity(phase == .reveal ? 0 : 1)
        .accessibilityLabel("Close")
    }

    // MARK: - Sequence

    private func waitForLanding() async {
        guard phase == .inTransit, let deliveryAt = capsule.deliveryAt else { return }
        let wait = deliveryAt.timeIntervalSinceNow
        // Begin the descent ~1.4s before touchdown so it lands on time.
        if wait > 1.4 { try? await Task.sleep(for: .seconds(wait - 1.4)) }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 1.4)) { shipDown = true }
        try? await Task.sleep(for: .seconds(1.4))
        SoundFX.play(.landing)
        hapticTick += 1
        try? await Task.sleep(for: .seconds(0.4))
        // Hatch pops; the package drops out.
        SoundFX.play(.pop)
        withAnimation(.spring(duration: 0.6, bounce: 0.55)) { shipHasCargo = false }
        try? await Task.sleep(for: .seconds(0.8))
        // Ship heads home.
        withAnimation(.easeIn(duration: 1.1)) { shipGone = true }
        try? await Task.sleep(for: .seconds(1.1))
        guard !Task.isCancelled else { return }
        phase = .waiting
    }

    private func open() async {
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
            phase = .shaking
            focus = true
        }
        shakeTrigger += 1
        for _ in 0..<9 {
            hapticTick += 1
            SoundFX.play(.tick)
            try? await Task.sleep(for: .seconds(0.12))
        }
        withAnimation(.spring(duration: 0.5)) { phase = .burst }
        withAnimation(.spring(duration: 0.8, bounce: 0.25)) { lid = 1 }
        burstArt = true
        confetti += 1
        SoundFX.play(.pop)
        try? await Task.sleep(for: .seconds(1.3))
        withAnimation(.spring(duration: 0.7, bounce: 0.2)) { phase = .reveal }
        didReveal = true
        SoundFX.play(.chime)
        try? await Task.sleep(for: .seconds(0.5))
        // Items surface one at a time, each with a little tick.
        while revealedCount < orderedItems.count, !Task.isCancelled {
            revealedCount += 1
            hapticTick += 1
            SoundFX.play(.tick)
            try? await Task.sleep(for: .seconds(0.45))
        }
    }

    private func revealAll() {
        revealedCount = orderedItems.count
    }

    private func finish() {
        if didReveal { onOpened() }
        onClose()
    }
}

#Preview {
    PackageOpeningView(
        capsule: Capsule(senderId: UUID(), recipientId: UUID(), crewLinkId: UUID(), status: .landed,
                         layout: CapsuleLayout(background: "sunset_wash", template: "scrapbook_collage", items: [
                            LayoutItem(id: "t1", type: .text, text: "the lake trip, right before it rained", font: "handwritten",
                                       x: 0.5, y: 0.35, w: 0.8, z: 1),
                            LayoutItem(id: "s1", type: .sticker, asset: "heart", x: 0.3, y: 0.65, w: 0.2, z: 2),
                            LayoutItem(id: "s2", type: .sticker, asset: "star", x: 0.72, y: 0.6, w: 0.18, rotation: 12, z: 3),
                         ], packageColor: "magenta")),
        senderName: "Maya", onOpened: {}, onClose: {})
}
