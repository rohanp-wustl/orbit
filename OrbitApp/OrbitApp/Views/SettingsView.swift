import SwiftUI

/// Settings (style sheet §5): the one light screen, deliberately plain —
/// labeled rows with chevrons and hairline dividers.
struct SettingsView: View {
    @Environment(OrbitStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(.orbitDisplay(32))
                        .foregroundStyle(Color.textOnLight)
                        .padding(.bottom, 20)

                    profileCard
                        .padding(.bottom, 24)

                    row("Account", symbol: "person.crop.circle.fill", hue: .accentBlue) { AccountView() }
                    divider
                    row("Notifications", symbol: "bell.badge.fill", hue: .orbitEmber) { NotificationsView() }
                    divider
                    row("Sound & haptics", symbol: "hand.tap.fill", hue: .orbitViolet) { SoundHapticsView() }
                    divider
                    row("About Orbit", symbol: "info.circle.fill", hue: .orbitGold) { AboutView() }
                }
                .padding(24)
                .padding(.bottom, 110)
            }
            .background(Color.cardWhite.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ShadedPlanet(hue: .accentBlue, size: 52, seed: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.currentUser.displayName)
                    .font(.orbitHeading(18))
                    .foregroundStyle(Color.textOnLight)
                Text("Level \(store.progress.level) · \(store.progress.rank) · \(store.progress.xp) XP")
                    .font(.orbitBody(13))
                    .foregroundStyle(Color.textOnLightMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.navSurfaceLight))
    }

    private var divider: some View {
        Rectangle().fill(Color.dividerLight).frame(height: 1)
    }

    private func row<Destination: View>(_ title: String, symbol: String, hue: Color,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hue.gradient))
                Text(title)
                    .font(.orbitHeading(16))
                    .foregroundStyle(Color.textOnLight)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textOnLightMuted)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Account

private struct AccountView: View {
    @Environment(OrbitStore.self) private var store
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                XPBar(progress: store.progress)
                    .padding(16)
                    .orbitCard(fill: .spaceDeep)

                Text("Achievements")
                    .font(.orbitHeading(18))
                    .foregroundStyle(Color.textOnLight)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(store.progress.achievements) { achievement in
                        AchievementBadge(achievement: achievement)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pilot ID")
                        .font(.orbitHeading(14))
                        .foregroundStyle(Color.textOnLightMuted)
                    Button {
                        UIPasteboard.general.string = store.currentUser.id.uuidString
                        copied = true
                    } label: {
                        HStack {
                            Text(store.currentUser.id.uuidString)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.textOnLight)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(copied ? Color.orbitSeafoam : Color.accentBlue)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.navSurfaceLight))
                    }
                    .buttonStyle(.plain)
                    Text("Your account is anonymous: no email or password. It lives on this phone.")
                        .font(.orbitBody(12))
                        .foregroundStyle(Color.textOnLightMuted)
                }
            }
            .padding(24)
            .padding(.bottom, 100)
        }
        .background(Color.cardWhite.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A shaded medal: bright and glowing when unlocked, flat gray with a lock
/// when not.
private struct AchievementBadge: View {
    let achievement: Achievement
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.unlocked
                          ? AnyShapeStyle(RadialGradient(colors: [achievement.hue.color.lightened(by: 0.35), achievement.hue.color,
                                                                  achievement.hue.color.darkened(by: 0.3)],
                                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 40))
                          : AnyShapeStyle(Color.dividerLight))
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 3).padding(4))
                    .shadow(color: achievement.unlocked ? achievement.hue.color.opacity(0.5) : .clear, radius: 8, y: 3)
                Image(systemName: achievement.unlocked ? achievement.symbol : "lock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(achievement.unlocked ? .white : Color.textOnLightMuted.opacity(0.6))
            }
            .frame(width: 66, height: 66)
            .scaleEffect(appeared ? 1 : 0.5)
            .rotationEffect(.degrees(appeared ? 0 : -30))

            Text(achievement.title)
                .font(.orbitHeading(12))
                .foregroundStyle(achievement.unlocked ? Color.textOnLight : Color.textOnLightMuted)
                .multilineTextAlignment(.center)
            Text(achievement.detail)
                .font(.orbitBody(10))
                .foregroundStyle(Color.textOnLightMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5).delay(Double.random(in: 0...0.3))) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(achievement.unlocked ? "unlocked" : "locked"). \(achievement.detail)")
    }
}

// MARK: - Notifications / haptics / about

/// Plain-language version of docs/PRIVACY.md.
private let privacyLines = [
    "Small photo thumbnails and one frame per video — never full files.",
    "Voice notes are transcribed on your phone; the audio never goes to the AI.",
    "Your notes are used to write drafts, then discarded — never saved.",
    "It never adds phone numbers, emails, addresses, or last names to a page.",
    "Only you and the person you send to can open a capsule.",
]

private struct NotificationsView: View {
    @Environment(OrbitStore.self) private var store
    @AppStorage("landingAlerts") private var landingAlerts = true
    @State private var textMe = false
    @State private var phone = ""
    @State private var saveState: String?

    var body: some View {
        Form {
            Section {
                Toggle("Landing alerts", isOn: $landingAlerts)
            } footer: {
                Text("A lock-screen notification (with a photo preview) when a capsule lands, even if Orbit is closed.")
            }
            Section {
                Toggle("Also text me in iMessage", isOn: $textMe)
                if textMe {
                    TextField("Your iPhone number", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                Button("Save") { Task { await save() } }
                    .disabled(textMe && phone.filter(\.isNumber).count < 10)
                if let saveState {
                    Text(saveState).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Ground Control in iMessage")
            } footer: {
                Text("Ground Control texts you the page, voice notes, and any question when a capsule lands. Reply in iMessage and it flies back as a capsule. Powered by Photon Spectrum.")
            }
        }
        .tint(.accentBlue)
        .navigationTitle("Notifications")
        .onAppear {
            textMe = store.currentUser.imessageUpdates ?? false
            phone = store.currentUser.phone ?? ""
        }
    }

    private func save() async {
        #if canImport(Supabase)
        do {
            try await CrewRepository.shared.updateIMessageSettings(
                userId: store.currentUser.id,
                phone: phone.isEmpty ? nil : IMessageInvite.normalize(phone),
                textMe: textMe)
            saveState = textMe ? "Saved. Ground Control will text \(IMessageInvite.normalize(phone))." : "Saved."
        } catch {
            saveState = "Couldn't save. (\(error.localizedDescription))"
        }
        #endif
    }
}

private struct SoundHapticsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true

    var body: some View {
        Form {
            Section {
                Toggle("Sound effects", isOn: $soundEnabled)
                Toggle("Haptics", isOn: $hapticsEnabled)
            } footer: {
                Text("Countdown beeps, the liftoff rumble, the landing thud, the unboxing pop and chime. Sounds follow your silent switch.")
            }
            Section {
                Button("Play a sample") { SoundFX.play(.chime) }
            }
        }
        .tint(.accentBlue)
        .navigationTitle("Sound & haptics")
        .sensoryFeedback(.impact(weight: .medium), trigger: hapticsEnabled) { _, on in on }
    }
}

private struct AboutView: View {
    @AppStorage("demoMode") private var demoMode = false

    var body: some View {
        ZStack {
            StarfieldBackground()
            ScrollView {
            VStack(spacing: 18) {
                Image("solar_system")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)
                Text("Orbit")
                    .font(.orbitDisplay(44))
                    .foregroundStyle(Color.textOnDark)
                Text("Send a piece of your world.")
                    .font(.orbitBody(16))
                    .foregroundStyle(Color.textOnDarkMuted)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.orbitBody(13))
                    .foregroundStyle(Color.textOnDarkMuted)
                CosmoView(size: 90, message: "Made for people far from home.")
                    .padding(.top, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("WHAT GROUND CONTROL SEES")
                        .font(.orbitHeading(11)).tracking(1.5).foregroundStyle(Color.skyGlass)
                    ForEach(privacyLines, id: \.self) { line in
                        Label(line, systemImage: "checkmark.shield.fill")
                            .font(.orbitBody(13))
                            .foregroundStyle(Color.textOnDark)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .orbitCard()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Offline demo mode", isOn: $demoMode)
                        .font(.orbitHeading(15))
                        .foregroundStyle(Color.textOnDark)
                        .tint(.accentBlue)
                    Text("Loads a seeded crew (Grandma Rose, Maya, Jordan) with no network, for demos when Wi-Fi fails. Turn off to go back to your real crew.")
                        .font(.orbitBody(12))
                        .foregroundStyle(Color.textOnDarkMuted)
                }
                .padding(16)
                .orbitCard()
            }
            .padding()
            }
        }
        .navigationTitle("About Orbit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        SettingsView()
        OrbitTabBar(selection: .constant(.settings), light: true, homeBadge: 1)
    }
    .environment(OrbitStore.preview)
}
