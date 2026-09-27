import SwiftUI

enum OrbitTab: CaseIterable, Hashable {
    case home, create, galaxy, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .create: "Create"
        case .galaxy: "Galaxy"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .create: "shippingbox.fill"
        case .galaxy: "moon.stars.fill"
        case .settings: "gearshape.fill"
        }
    }
}

/// The signed-in app: four tabs under a floating pill tab bar (style sheet
/// §4), with the capsule opening as a full-screen takeover and reward
/// toasts layered over everything.
struct MainTabView: View {
    @State private var store: OrbitStore
    /// Survives tab switches, so a half-built package isn't lost.
    @State private var draft = CapsuleDraft()

    init(currentUser: AppUser, demoMode: Bool = false) {
        _store = State(initialValue: demoMode ? OrbitStore.demo(for: currentUser) : OrbitStore(currentUser: currentUser))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch store.selectedTab {
                case .home: HomeView()
                case .create: CreateView(draft: draft)
                case .galaxy: GalaxyView()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity)

            OrbitTabBar(selection: $store.selectedTab,
                        light: store.selectedTab == .settings,
                        homeBadge: store.incoming.filter { $0.status == .landed }.count)
        }
        .animation(.easeInOut(duration: 0.2), value: store.selectedTab)
        .ignoresSafeArea(.keyboard)
        // Settings is the one light screen; everything else is space.
        .preferredColorScheme(store.selectedTab == .settings ? .light : .dark)
        .environment(store)
        .task {
            await LandingNotifications.requestPermission()
            await store.start()
        }
        // Re-armed when the set of capsules changes (status-only updates keep the same ids).
        .task(id: store.capsules.map(\.id)) { await store.markLandedWhenDue() }
        .overlay {
            if let reward = store.reward {
                RewardToast(reward: reward) { store.reward = nil }
                    .id(reward.id)
            }
        }
        .fullScreenCover(item: $store.presentedCapsule) { capsule in
            CapsuleDetailView(capsule: capsule)
                .environment(store)
        }
    }
}

/// Floating pill tab bar: white on dark screens, light gray on Settings.
/// The selected tab gets a sliding accent bubble and a bounce.
struct OrbitTabBar: View {
    @Binding var selection: OrbitTab
    var light: Bool
    var homeBadge: Int

    @Namespace private var bubble
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OrbitTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    ZStack {
                        if selection == tab {
                            SwiftUI.Capsule()
                                .fill(Color.accentBlue.opacity(0.12))
                                .matchedGeometryEffect(id: "bubble", in: bubble)
                        }
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.bounce, value: selection == tab)
                            Text(tab.title)
                                .font(.orbitHeading(10))
                        }
                        .foregroundStyle(selection == tab ? Color.accentBlue : Color.navIconInactive.darkened(by: 0.25))
                        .overlay(alignment: .topTrailing) {
                            if tab == .home && homeBadge > 0 {
                                Text("\(homeBadge)")
                                    .font(.orbitHeading(10))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Circle().fill(Color.orbitEmber))
                                    .offset(x: 10, y: -4)
                                    .transition(.scale)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            SwiftUI.Capsule()
                .fill(light ? Color.navSurfaceLight : Color.navSurfaceDark)
                .shadow(color: .black.opacity(light ? 0.12 : 0.4), radius: 18, y: 8)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .animation(.spring(duration: 0.35, bounce: 0.35), value: selection)
        .animation(.spring, value: homeBadge)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in hapticsEnabled }
    }
}
