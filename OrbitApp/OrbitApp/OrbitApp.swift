import SwiftUI

@main
struct OrbitApp: App {
    // Supabase needs no launch-time configuration call — OrbitSupabase.client
    // is a lazy static, initialized the first time anything touches it.

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Routing: signed out → Onboarding, signed in → CrewHome, carrying the
/// AppUser CrewHomeView needs to know whose capsules to fetch/subscribe to.
struct RootView: View {
    @State private var currentUser: AppUser?
    /// True until the saved-session check finishes, so returning users don't
    /// see a flash of OnboardingView before landing on CrewHome.
    @State private var isRestoring = true
    @AppStorage("demoMode") private var demoMode = false

    var body: some View {
        Group {
            if isRestoring {
                ZStack {
                    StarfieldBackground()
                    ShadedPlanet(hue: .accentBlue, size: 70)
                }
                .preferredColorScheme(.dark)
            } else if let currentUser {
                // MainTabView owns the color scheme from here (light only on Settings).
                // .id rebuilds the whole session when Offline demo mode is toggled.
                MainTabView(currentUser: currentUser, demoMode: demoMode)
                    .id(demoMode)
                    .transition(.opacity)
            } else {
                OnboardingView(onSignedIn: { user in
                    withAnimation(.easeInOut(duration: 0.5)) { currentUser = user }
                })
                .preferredColorScheme(.dark)
                .transition(.opacity)
            }
        }
        .task {
            #if canImport(Supabase)
            currentUser = await CrewRepository.shared.restoreSignedInUser()
            #endif
            isRestoring = false
        }
    }
}
