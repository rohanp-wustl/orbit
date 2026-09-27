import SwiftUI

/// Home / launchpad (style sheet §5): the docked rocket on its pad, the
/// packages that have landed for you waiting beside it, progress, and the
/// mission log.
struct HomeView: View {
    @Environment(OrbitStore.self) private var store
    @AppStorage("seenCosmoIntro") private var seenCosmoIntro = false
    @State private var rocketWiggle = 0
    @State private var showScrapbook = false

    private var scrapbookPages: [Capsule] {
        store.capsules.filter { $0.recipientId == store.currentUser.id && $0.status == .opened }
    }

    var body: some View {
        ZStack {
            StarfieldBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    XPBar(progress: store.progress)
                        .padding(16)
                        .orbitCard()
                    launchpadScene
                    Button {
                        store.selectedTab = .create
                    } label: {
                        Label("Send a package", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(OrbitPillButtonStyle())

                    statsRow
                    InAppWidgetPreviewView(latestCapsule: store.incoming.first,
                                           senderName: store.incoming.first.map { store.name(for: $0.senderId) })
                        .onTapGesture {
                            if let capsule = store.incoming.first { store.presentedCapsule = capsule }
                        }
                    scrapbookCard
                    missionLog

                    if let loadError = store.loadError {
                        Text(loadError)
                            .font(.orbitBody(12))
                            .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
                    }
                }
                .padding(20)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.reload() }

            if showIntro { cosmoIntro }
        }
        .sheet(isPresented: $showScrapbook) {
            ScrapbookView().environment(store)
        }
    }

    /// Opened capsules live on as scrapbook pages.
    private var scrapbookCard: some View {
        Button {
            showScrapbook = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    ForEach(0..<3, id: \.self) { layer in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(layer == 2 ? Color.kraftPaper : Color.kraftPaper.darkened(by: 0.08 * Double(2 - layer)))
                            .frame(width: 46, height: 60)
                            .rotationEffect(.degrees(Double(layer - 1) * 8))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                    Rectangle().fill(Color.skyGlass.opacity(0.6)).frame(width: 24, height: 8).offset(y: -30)
                }
                .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR SCRAPBOOK")
                        .font(.orbitHeading(10))
                        .tracking(1.5)
                        .foregroundStyle(Color.orbitGold)
                    Text(scrapbookPages.isEmpty ? "Empty for now" : "\(scrapbookPages.count) page\(scrapbookPages.count == 1 ? "" : "s")")
                        .font(.orbitHeading(17))
                        .foregroundStyle(Color.textOnDark)
                    Text("Every capsule you open is taped in here.")
                        .font(.orbitBody(13))
                        .foregroundStyle(Color.textOnDarkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.textOnDarkMuted)
            }
            .padding(16)
            .orbitCard(cornerRadius: 26)
        }
        .buttonStyle(.plain)
    }

    private var showIntro: Bool {
        !seenCosmoIntro && store.crewMembers.isEmpty && store.capsules.isEmpty
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your launchpad")
                    .font(.orbitDisplay(30))
                    .foregroundStyle(Color.textOnDark)
                Text("Hi, \(store.currentUser.displayName) 👋")
                    .font(.orbitBody(15))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
            Spacer()
        }
    }

    // MARK: - Launchpad scene

    private var launchpadScene: some View {
        ZStack(alignment: .bottom) {
            ShadedPlanet(hue: .orbitMagenta, size: 70, surface: .banded, ringed: true, seed: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 6)
            ShadedPlanet(hue: .orbitGold, size: 26, seed: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 40)
                .padding(.leading, 20)

            GantryTower(height: 190)
                .offset(x: -88, y: -30)

            // Pulls the rocket's engine down onto the platform: the flame gap
            // (190 × flameSpace) plus ~a third of the pad's height to reach its deck.
            VStack(spacing: -(190 * RocketView.flameSpace + 240 * 289 / 843 * 0.35)) {
                HoveringRocket()
                    .keyframeAnimator(initialValue: 0.0, trigger: rocketWiggle) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } keyframes: { _ in
                        SpringKeyframe(-8, duration: 0.1)
                        SpringKeyframe(8, duration: 0.12)
                        SpringKeyframe(0, duration: 0.3)
                    }
                    .onTapGesture {
                        rocketWiggle += 1
                        Task {
                            try? await Task.sleep(for: .seconds(0.35))
                            store.selectedTab = .create
                        }
                    }
                    .accessibilityLabel("Rocket. Tap to send a package")
                    .accessibilityAddTraits(.isButton)
                    .zIndex(1) // in front of the pad, not tucked behind its rim
                Image("launchpad")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)
            }

            waitingPackages
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)

            if !store.outgoingInFlight.isEmpty {
                Label("\(store.outgoingInFlight.count) in orbit", systemImage: "arrow.up.forward")
                    .font(.orbitHeading(12))
                    .foregroundStyle(Color.orbitGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SwiftUI.Capsule().fill(Color.spaceDeep.opacity(0.8)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: 320)
    }

    /// Up to three packages sent to me, beside the pad. Landed ones wobble
    /// with a "!" to be opened; in-transit ones are ghosted with a countdown.
    private var waitingPackages: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(store.incoming.prefix(3).enumerated()), id: \.element.id) { index, capsule in
                WaitingPackage(capsule: capsule, index: index)
                    .onTapGesture { store.presentedCapsule = capsule }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.6, bounce: 0.45), value: store.incoming.map(\.id))
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: store.progress.launched, label: "Launched", symbol: "paperplane.fill", hue: .ember)
            StatTile(value: store.progress.unboxed, label: "Unboxed", symbol: "gift.fill", hue: .magenta)
            StatTile(value: store.progress.crewCount, label: "Crew", symbol: "person.2.fill", hue: .seafoam)
        }
    }

    // MARK: - Mission log

    private var missionLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mission log")
                .font(.orbitHeading(18))
                .foregroundStyle(Color.textOnDark)

            if store.capsules.isEmpty {
                HStack(spacing: 16) {
                    CosmoView(size: 70, floating: true, pose: .sleep)
                    Text(store.crewMembers.isEmpty
                         ? "No crew yet. Invite someone from the Galaxy tab!"
                         : "Nothing launched yet. Your first package is one tap away.")
                        .font(.orbitBody(14))
                        .foregroundStyle(Color.textOnDarkMuted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .orbitCard()
            } else {
                ForEach(store.capsules.prefix(8)) { capsule in
                    Button {
                        store.presentedCapsule = capsule
                    } label: {
                        MissionLogRow(capsule: capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - First-run intro

    private var cosmoIntro: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { withAnimation { seenCosmoIntro = true } }
            VStack(spacing: 24) {
                CosmoView(size: 150, message: "Let's send your first package!")
                Text("First, add someone to your crew. Share an invite code from Galaxy.")
                    .font(.orbitBody(15))
                    .foregroundStyle(Color.textOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Find my crew") {
                    withAnimation { seenCosmoIntro = true }
                    store.selectedTab = .galaxy
                }
                .buttonStyle(OrbitPillButtonStyle(fullWidth: false))
                Button("Maybe later") { withAnimation { seenCosmoIntro = true } }
                    .font(.orbitHeading(14))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
        }
        .transition(.opacity)
    }
}

/// The parked rocket, gently hovering a few points above the pad.
private struct HoveringRocket: View {
    @State private var hover = false

    var body: some View {
        RocketView(height: 190)
            .offset(y: hover ? -6 : 0)
            .shadow(color: .skyGlass.opacity(0.25), radius: 20)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { hover = true }
            }
    }
}

/// A package beside the pad.
private struct WaitingPackage: View {
    let capsule: Capsule
    let index: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secondsLeft = Int((capsule.deliveryAt ?? .distantPast).timeIntervalSince(context.date).rounded(.up))
            let landed = capsule.status == .landed || secondsLeft <= 0
            let hue = OrbitHue.named(capsule.layout.packageColor).color
            VStack(spacing: 4) {
                Group {
                    if landed {
                        GiftBoxView(hue: hue, size: index == 0 ? 58 : 46)
                            .phaseAnimator([0.0, -7, 7, -4, 0]) { view, angle in
                                view.rotationEffect(.degrees(angle), anchor: .bottom)
                            } animation: { _ in .easeInOut(duration: 0.18) }
                            .overlay(alignment: .topTrailing) {
                                Text("!")
                                    .font(.orbitDisplay(14))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.orbitEmber))
                                    .offset(x: 4, y: 6)
                            }
                            .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                    } else {
                        // Still flying: the capsule's ship on approach, package in the hatch.
                        RocketView(height: index == 0 ? 78 : 60, thrust: 0.6, hue: hue, cargo: hue)
                            .phaseAnimator([0.0, -8, 0]) { view, bob in
                                view.offset(y: bob)
                            } animation: { _ in .easeInOut(duration: 0.9) }
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.7, bounce: 0.45), value: landed)

                Text(landed ? "Open me" : "ETA \(LaunchView.duration(max(secondsLeft, 0)))")
                    .font(.orbitHeading(11))
                    .foregroundStyle(landed ? Color.orbitGold : Color.skyGlass)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Package")
        .accessibilityAddTraits(.isButton)
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let symbol: String
    let hue: OrbitHue

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(hue.color)
                .shadow(color: hue.color.opacity(0.6), radius: 6)
            Text("\(value)")
                .font(.orbitDisplay(24))
                .foregroundStyle(Color.textOnDark)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.orbitBody(12))
                .foregroundStyle(Color.textOnDarkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .orbitCard(cornerRadius: 20)
        .animation(.spring, value: value)
        .accessibilityElement(children: .combine)
    }
}

/// One capsule in the mission log.
private struct MissionLogRow: View {
    @Environment(OrbitStore.self) private var store
    let capsule: Capsule

    private var isSender: Bool { capsule.senderId == store.currentUser.id }

    var body: some View {
        HStack(spacing: 14) {
            GiftBoxView(hue: OrbitHue.named(capsule.layout.packageColor).color, size: 34, showsShadow: false)
                .frame(width: 42, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(isSender ? "To \(store.name(for: capsule.recipientId))" : "From \(store.name(for: capsule.senderId))")
                    .font(.orbitHeading(15))
                    .foregroundStyle(Color.textOnDark)
                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.orbitBody(12))
                        .foregroundStyle(statusColor)
                    if capsule.cameFromIMessage {
                        Label("via iMessage", systemImage: "message.fill")
                            .font(.orbitHeading(10))
                            .foregroundStyle(Color.orbitSeafoam)
                    }
                }
            }
            Spacer()
            Text(capsule.createdAt, style: .relative)
                .font(.orbitBody(11))
                .foregroundStyle(Color.textOnDarkMuted)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.textOnDarkMuted)
        }
        .padding(14)
        .orbitCard(cornerRadius: 20)
    }

    private var statusText: String {
        switch capsule.status {
        case .draft: "Draft"
        case .launched, .inTransit: isSender ? "In orbit" : "Incoming"
        case .landed: isSender ? "Landed · waiting to be opened" : "Landed! Tap to open"
        case .opened: isSender ? "Opened ✓" : "Unboxed"
        }
    }

    private var statusColor: Color {
        switch capsule.status {
        case .landed: isSender ? .textOnDarkMuted : .orbitGold
        case .opened: .orbitSeafoam
        default: .skyGlass
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        HomeView()
        OrbitTabBar(selection: .constant(.home), light: false, homeBadge: 1)
    }
    .environment(OrbitStore.preview)
}
