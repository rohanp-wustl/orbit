import SwiftUI
#if canImport(Supabase)
import Supabase
#endif

/// Sign-in is Supabase Auth's anonymous sign-in, not Sign in with Apple — a
/// free Apple ID's Personal Team can't sign that entitlement. See
/// docs/PUSH_AND_WIDGET_PLAN.md and docs/FIRST_3_HOURS.md. A name is all
/// that's collected; that name becomes the `profiles` row Ground Control and
/// the crew-link flow both key off of.
struct OnboardingView: View {
    var onSignedIn: (AppUser) -> Void

    @State private var displayName: String = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            StarfieldBackground()

            // The big planet rising out of the corner (Sign In mockup).
            ShadedPlanet(hue: .orbitMagenta, size: 300, surface: .banded, spinSpeed: 0.15, seed: 6)
                .offset(x: 140, y: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 200)
                .ignoresSafeArea()
            ShadedPlanet(hue: .orbitSeafoam, size: 40, seed: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 40)
                .padding(.top, 110)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 22) {
                Spacer()
                // A little moon on a tilted orbit around the wordmark: it
                // passes behind the text on the far side, in front on the near side.
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    let angle = timeline.date.timeIntervalSinceReferenceDate * 1.1
                    let inFront = sin(angle) > 0
                    ZStack {
                        Text("Orbit")
                            .font(.orbitDisplay(64))
                            .foregroundStyle(Color.textOnDark)
                            .shadow(color: .accentBlue.opacity(0.6), radius: 20)
                            .zIndex(1)
                        ShadedPlanet(hue: .orbitGold, size: inFront ? 18 : 13, spinSpeed: 0)
                            .offset(x: cos(angle) * 115, y: sin(angle) * 26 - 4)
                            .zIndex(inFront ? 2 : 0)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.6)
                Text("Send a piece of your world")
                    .font(.orbitBody(17))
                    .foregroundStyle(Color.textOnDarkMuted)

                Spacer()

                VStack(spacing: 14) {
                    TextField("", text: $displayName, prompt: Text("What should your crew call you?")
                        .foregroundStyle(Color.textOnDarkMuted))
                        .font(.orbitHeading(17))
                        .foregroundStyle(Color.textOnDark)
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await signIn() } }
                        .padding(.vertical, 16)
                        .orbitCard(fill: .panelNavy, cornerRadius: 30)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.orbitBody(12))
                            .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        Label(isWorking ? "Preparing for launch…" : "Get started", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(OrbitPillButtonStyle())
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .offset(y: appeared ? 0 : 80)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 1.1, bounce: 0.35)) { appeared = true }
        }
        .onTapGesture { nameFocused = false }
    }

    private func signIn() async {
        // Keyboard "Go" can fire this with an empty name or mid-request.
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty, !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        #if canImport(Supabase)
        do {
            // VERSION NOTE: `signInAnonymously()` is supabase-swift's current
            // method name for this as of writing — confirm against
            // https://supabase.com/docs/reference/swift/auth-signinanonymously
            // if this doesn't compile against your resolved package version.
            // Reuse a saved session if one exists (e.g. signed in before but
            // the profile insert failed) instead of minting a new account.
            let existingSession = try? await OrbitSupabase.client.auth.session
            let session = if let existingSession { existingSession } else { try await OrbitSupabase.client.auth.signInAnonymously() }
            let user = AppUser(id: session.user.id, displayName: displayName)
            try await OrbitSupabase.client.from("profiles").upsert(user).execute()
            onSignedIn(user)
        } catch {
            errorMessage = "Couldn't sign in — check projectURL/anonKey in SupabaseConfig.swift, and that docs/SUPABASE_SETUP.sql has been run. (\(error.localizedDescription))"
        }
        #else
        errorMessage = "Add the Supabase Swift package first — see docs/FIRST_3_HOURS.md."
        #endif
    }
}

#Preview {
    OnboardingView(onSignedIn: { _ in })
}
