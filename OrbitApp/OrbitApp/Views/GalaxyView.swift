import SwiftUI

/// Galaxy (style sheet §5): you're the blue home planet at the center, each
/// crew member is a planet in their own hue on a dashed orbit, and capsules
/// in flight are little rockets crossing between planets in real time.
/// Also where the crew is managed: invite codes and joining.
struct GalaxyView: View {
    @Environment(OrbitStore.self) private var store

    @State private var showJoinSheet = false
    @State private var selectedMember: AppUser?
    @State private var inviteError: String?
    @State private var isCreatingInvite = false
    @State private var showIMessageInvite = false

    /// Stable order so planets don't swap orbits between reloads.
    private var members: [AppUser] {
        store.crewMembers.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    var body: some View {
        ZStack {
            StarfieldBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    orbitSystem
                    if !members.isEmpty {
                        Text("Closer orbits = more recent capsules. Planets drift out when it's been a while.")
                            .font(.orbitBody(12))
                            .foregroundStyle(Color.textOnDarkMuted)
                            .multilineTextAlignment(.center)
                    }
                    if members.isEmpty { emptyCard }
                    ForEach(store.pendingInvites) { invite in
                        InviteCard(invite: invite)
                    }
                    ForEach(store.imessageInvites.filter { $0.status != .sent }) { invite in
                        IMessageInviteStatus(invite: invite)
                    }
                    if let inviteError {
                        Text(inviteError)
                            .font(.orbitBody(12))
                            .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
                    }
                    crewButtons
                }
                .padding(20)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.reload() }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinCrewSheet()
                .environment(store)
        }
        .sheet(isPresented: $showIMessageInvite) {
            IMessageInviteSheet()
                .environment(store)
        }
        .task { await store.refreshIMessageInvites() }
        .sheet(item: $selectedMember) { member in
            MemberSheet(member: member)
                .environment(store)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Galaxy")
                    .font(.orbitDisplay(30))
                    .foregroundStyle(Color.textOnDark)
                Text(members.isEmpty ? "Just you out here, for now" : "\(members.count) in your crew")
                    .font(.orbitBody(15))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
            Spacer()
        }
    }

    // MARK: - Orbit system

    private var orbitSystem: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let center = CGPoint(x: side / 2, y: side / 2)
            // Three orbits: close (exchanged in the last 3 days), mid (2 weeks), far.
            let radii = [side * 0.3, side * 0.39, side * 0.47]

            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(radii, id: \.self) { radius in
                        Circle()
                            .stroke(Color.textOnDarkMuted.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [3, 7]))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(center)
                    }

                    ForEach(flights(now: timeline.date), id: \.capsule.id) { flight in
                        ShipInFlight(from: position(of: flight.from, center: center, radii: radii, time: time),
                                     to: position(of: flight.to, center: center, radii: radii, time: time),
                                     progress: flight.progress,
                                     hue: OrbitHue.named(flight.capsule.layout.packageColor).color)
                    }

                    VStack(spacing: 6) {
                        ShadedPlanet(hue: .accentBlue, size: 72, surface: .cratered, seed: 2)
                        Text("You")
                            .font(.orbitHeading(13))
                            .foregroundStyle(Color.textOnDark)
                    }
                    .position(x: center.x, y: center.y + 10)

                    ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                        Button {
                            selectedMember = member
                        } label: {
                            VStack(spacing: 4) {
                                ShadedPlanet(hue: OrbitHue.forUser(member.id).color, size: 46,
                                             surface: [.cratered, .banded, .smooth][index % 3],
                                             ringed: index % 3 == 1, seed: UInt64(index + 5))
                                Label {
                                    Text(member.displayName)
                                } icon: {
                                    if member.livesInIMessage {
                                        Image(systemName: "message.fill").foregroundStyle(Color.orbitSeafoam)
                                    }
                                }
                                    .labelStyle(.titleAndIcon)
                                    .font(.orbitHeading(12))
                                    .foregroundStyle(Color.textOnDark)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(SwiftUI.Capsule().fill(Color.spaceDeep.opacity(0.7)))
                            }
                        }
                        .buttonStyle(.plain)
                        .position(orbitPoint(index: index, center: center, radii: radii, time: time))
                        .accessibilityLabel("\(member.displayName)'s planet")
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Distance in the galaxy = how recently you two exchanged a capsule.
    /// 0 = within 3 days, 1 = within 2 weeks, 2 = longer (or never). Planets
    /// drift outward when a crew member hasn't heard from you — a gentle
    /// nudge that comes from the data, not a notification.
    private func ring(for memberId: UUID) -> Int {
        let last = store.capsules
            .filter { $0.senderId == memberId || $0.recipientId == memberId }
            .map { $0.launchedAt ?? $0.createdAt }
            .max()
        guard let last else { return 2 }
        let days = Date().timeIntervalSince(last) / 86_400
        return days < 3 ? 0 : (days < 14 ? 1 : 2)
    }

    /// Where crew member #index is right now. Inner orbits turn faster,
    /// like real ones; members sharing a ring are spaced evenly around it.
    private func orbitPoint(index: Int, center: CGPoint, radii: [CGFloat], time: Double) -> CGPoint {
        let member = members[index]
        let ringIndex = ring(for: member.id)
        let sameRing = members.filter { ring(for: $0.id) == ringIndex }
        let slot = sameRing.firstIndex(of: member) ?? 0
        let angle = Double(slot) * (2 * .pi / Double(max(1, sameRing.count))) + Double(ringIndex) * 1.1
            + time * [0.12, 0.08, 0.05][ringIndex]
        return CGPoint(x: center.x + cos(angle) * radii[ringIndex], y: center.y + sin(angle) * radii[ringIndex])
    }

    private func position(of userId: UUID, center: CGPoint, radii: [CGFloat], time: Double) -> CGPoint {
        guard let index = members.firstIndex(where: { $0.id == userId }) else { return center }
        return orbitPoint(index: index, center: center, radii: radii, time: time)
    }

    private struct Flight {
        let capsule: Capsule
        let from: UUID
        let to: UUID
        let progress: Double
    }

    /// Capsules still traveling, with how far along their trip they are.
    private func flights(now: Date) -> [Flight] {
        store.capsules.compactMap { capsule in
            guard capsule.status == .launched || capsule.status == .inTransit,
                  let launchedAt = capsule.launchedAt, let deliveryAt = capsule.deliveryAt,
                  deliveryAt > now else { return nil }
            let total = deliveryAt.timeIntervalSince(launchedAt)
            let progress = total > 0 ? min(1, max(0, now.timeIntervalSince(launchedAt) / total)) : 1
            return Flight(capsule: capsule, from: capsule.senderId, to: capsule.recipientId, progress: progress)
        }
    }

    // MARK: - Crew management

    private var emptyCard: some View {
        HStack(spacing: 16) {
            CosmoView(size: 80, pose: .sleep)
            VStack(alignment: .leading, spacing: 6) {
                Text("Your galaxy is empty")
                    .font(.orbitHeading(17))
                    .foregroundStyle(Color.textOnDark)
                Text("Invite someone with a code, or join theirs. Each crew member earns +\(PilotProgress.xpPerCrewMember) XP.")
                    .font(.orbitBody(13))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
        }
        .padding(16)
        .orbitCard()
    }

    private var crewButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { await createInvite() }
                } label: {
                    Label(isCreatingInvite ? "Creating…" : "Invite", systemImage: "person.badge.plus")
                }
                .buttonStyle(OrbitPillButtonStyle())
                .disabled(isCreatingInvite)

                Button {
                    showJoinSheet = true
                } label: {
                    Label("Join", systemImage: "number")
                }
                .buttonStyle(OrbitPillButtonStyle(color: .orbitViolet))
            }
            // For crew who won't install an app (hi, Grandma): Ground Control
            // texts them, and they reply right in iMessage.
            Button {
                showIMessageInvite = true
            } label: {
                Label("Invite by iMessage — no app needed", systemImage: "message.fill")
            }
            .buttonStyle(OrbitPillButtonStyle(color: .orbitSeafoam, textColor: .spaceDeep))
        }
    }

    private func createInvite() async {
        isCreatingInvite = true
        defer { isCreatingInvite = false }
        do {
            _ = try await store.createInvite()
            inviteError = nil
        } catch {
            inviteError = "Couldn't create an invite. (\(error.localizedDescription))"
        }
    }
}

/// A little rocket flying from one planet to another, nose-first, with a
/// dotted trail behind it.
private struct ShipInFlight: View {
    let from: CGPoint
    let to: CGPoint
    let progress: Double
    let hue: Color

    var body: some View {
        let x = from.x + (to.x - from.x) * progress
        let y = from.y + (to.y - from.y) * progress
        let heading = atan2(to.y - from.y, to.x - from.x) + .pi / 2
        ZStack {
            ForEach(1..<4) { step in
                let back = max(0, progress - Double(step) * 0.05)
                Circle()
                    .fill(Color.cloudGray.opacity(0.7 - Double(step) * 0.15))
                    .frame(width: CGFloat(7 - step), height: CGFloat(7 - step))
                    .position(x: from.x + (to.x - from.x) * back, y: from.y + (to.y - from.y) * back)
            }
            RocketView(height: 38, thrust: 0.6, hue: hue, cargo: hue)
                .rotationEffect(.radians(heading))
                .position(x: x, y: y)
        }
        .allowsHitTesting(false)
    }
}

/// An open invite: the code, share/copy buttons, and a radar ping while
/// waiting for someone to join.
private struct InviteCard: View {
    let invite: CrewLink
    @State private var ping = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ForEach(0..<2) { ring in
                    Circle()
                        .stroke(Color.orbitSeafoam.opacity(ping ? 0 : 0.8), lineWidth: 2)
                        .scaleEffect(ping ? 2.2 : 0.6)
                        .animation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(ring)), value: ping)
                }
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.orbitSeafoam)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Waiting for crew…")
                    .font(.orbitBody(12))
                    .foregroundStyle(Color.textOnDarkMuted)
                Text(invite.inviteCode)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.textOnDark)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(spacing: 8) {
                ShareLink(item: "Join my crew on Orbit! Enter code \(invite.inviteCode) in Galaxy → Join.") {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.accentBlue))
                        .foregroundStyle(.white)
                }
                Button {
                    UIPasteboard.general.string = invite.inviteCode
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.spaceDeep))
                        .foregroundStyle(copied ? Color.orbitSeafoam : .white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.success, trigger: copied)
            }
        }
        .padding(16)
        .orbitCard()
        .onAppear { ping = true }
    }
}

/// Details for a crew member's planet.
private struct MemberSheet: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let member: AppUser

    private var shared: [Capsule] {
        store.capsules.filter { $0.senderId == member.id || $0.recipientId == member.id }
    }

    var body: some View {
        ZStack {
            StarfieldBackground(base: .panelNavy, starCount: 30)
            ScrollView {
                VStack(spacing: 18) {
                    ShadedPlanet(hue: OrbitHue.forUser(member.id).color, size: 110, surface: .banded, ringed: true, seed: 9)
                        .padding(.top, 30)
                    Text(member.displayName)
                        .font(.orbitDisplay(30))
                        .foregroundStyle(Color.textOnDark)
                    HStack(spacing: 12) {
                        stat("\(shared.filter { $0.senderId == store.currentUser.id }.count)", "Sent to them")
                        stat("\(shared.filter { $0.senderId == member.id }.count)", "From them")
                    }
                    Button {
                        store.preselectedRecipient = member.id
                        store.selectedTab = .create
                        dismiss()
                    } label: {
                        Label("Send \(member.displayName) a package", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(OrbitPillButtonStyle())

                    ForEach(shared.prefix(6)) { capsule in
                        Button {
                            dismiss()
                            store.presentedCapsule = capsule
                        } label: {
                            HStack {
                                GiftBoxView(hue: OrbitHue.named(capsule.layout.packageColor).color, size: 28, showsShadow: false)
                                    .frame(width: 36, height: 38)
                                Text(capsule.senderId == member.id ? "From \(member.displayName)" : "To \(member.displayName)")
                                    .font(.orbitHeading(14))
                                    .foregroundStyle(Color.textOnDark)
                                Spacer()
                                Text(capsule.createdAt, style: .date)
                                    .font(.orbitBody(12))
                                    .foregroundStyle(Color.textOnDarkMuted)
                            }
                            .padding(12)
                            .orbitCard(fill: .spaceDeep, cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.orbitDisplay(24)).foregroundStyle(Color.textOnDark)
            Text(label).font(.orbitBody(12)).foregroundStyle(Color.textOnDarkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .orbitCard(fill: .spaceDeep, cornerRadius: 18)
    }
}

/// Enter a friend's 6-character invite code to join their crew.
struct JoinCrewSheet: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var shake = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Join a crew")
                .font(.orbitDisplay(26))
                .foregroundStyle(Color.textOnDark)
                .padding(.top, 24)
            Text("Enter the 6-character code your friend shared.")
                .font(.orbitBody(14))
                .foregroundStyle(Color.textOnDarkMuted)

            TextField("", text: $code, prompt: Text("K7MPQ2").foregroundStyle(Color.textOnDarkMuted.opacity(0.4)))
                .font(.system(size: 34, weight: .heavy, design: .monospaced))
                .tracking(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textOnDark)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 16)
                .orbitCard(fill: .spaceDeep, cornerRadius: 20)
                .keyframeAnimator(initialValue: 0.0, trigger: shake) { view, x in
                    view.offset(x: x)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-12, duration: 0.06)
                        LinearKeyframe(12, duration: 0.08)
                        LinearKeyframe(-8, duration: 0.08)
                        LinearKeyframe(0, duration: 0.08)
                    }
                }
                .onChange(of: code) { _, new in
                    if new.count > 6 { code = String(new.prefix(6)) }
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.orbitBody(13))
                    .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
                    .multilineTextAlignment(.center)
            }

            Button(isWorking ? "Docking…" : "Join crew") {
                Task { await join() }
            }
            .buttonStyle(OrbitPillButtonStyle())
            .disabled(code.trimmingCharacters(in: .whitespaces).count < 6 || isWorking)
            Spacer()
        }
        .padding(24)
        .background(StarfieldBackground(base: .panelNavy, starCount: 25))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.error, trigger: shake)
    }

    private func join() async {
        isWorking = true
        defer { isWorking = false }
        do {
            if try await store.join(code: code) {
                dismiss()
            } else {
                errorMessage = "That code didn't work. It may be mistyped, already used, or your own."
                shake += 1
            }
        } catch {
            errorMessage = "Couldn't join. (\(error.localizedDescription))"
            shake += 1
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        GalaxyView()
        OrbitTabBar(selection: .constant(.galaxy), light: false, homeBadge: 1)
    }
    .environment(OrbitStore.preview)
}


/// Add someone by name + phone. Ground Control (agent/) texts them; they get
/// capsules in iMessage and reply there — no app install.
private struct IMessageInviteSheet: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && phone.filter(\.isNumber).count >= 10 && !isSending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.spaceDeep)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.orbitSeafoam))
                Text("Invite by iMessage")
                    .font(.orbitDisplay(24))
                    .foregroundStyle(Color.textOnDark)
            }
            .padding(.top, 24)
            Text("Ground Control will text them. Your capsules land in their Messages app, and anything they text back flies back to you as a capsule. They never need to install Orbit.")
                .font(.orbitBody(14))
                .foregroundStyle(Color.textOnDarkMuted)

            TextField("", text: $name, prompt: Text("Their name (e.g. Grandma Rose)").foregroundStyle(Color.textOnDarkMuted))
                .font(.orbitHeading(17))
                .foregroundStyle(Color.textOnDark)
                .textInputAutocapitalization(.words)
                .padding(14)
                .orbitCard(fill: .spaceDeep, cornerRadius: 16)
            TextField("", text: $phone, prompt: Text("Their iPhone number").foregroundStyle(Color.textOnDarkMuted))
                .font(.orbitHeading(17))
                .foregroundStyle(Color.textOnDark)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(14)
                .orbitCard(fill: .spaceDeep, cornerRadius: 16)

            if let errorMessage {
                Text(errorMessage).font(.orbitBody(13)).foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
            }

            Button {
                Task { await send() }
            } label: {
                Label(isSending ? "Asking Ground Control…" : "Have Ground Control text them", systemImage: "paperplane.fill")
            }
            .buttonStyle(OrbitPillButtonStyle(color: .orbitSeafoam, textColor: .spaceDeep))
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.5)
            Spacer()
        }
        .padding(24)
        .background(StarfieldBackground(base: .panelNavy, starCount: 25))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        do {
            // Dismiss right away; the status card in Galaxy tracks delivery.
            let task = Task { try await store.inviteByIMessage(name: trimmedName, phone: phone) }
            try await Task.sleep(for: .milliseconds(300))
            dismiss()
            try await task.value
        } catch {
            errorMessage = "Couldn't send the invite. (\(error.localizedDescription))"
        }
    }
}

/// Live status of an iMessage invite while Ground Control delivers it.
private struct IMessageInviteStatus: View {
    let invite: IMessageInvite

    var body: some View {
        if invite.status == .waiting, let line = invite.formattedLine {
            waitingCard(line: line)
        } else {
            statusCard
        }
    }

    /// Photon's shared lines can only text people who've texted in once.
    private func waitingCard(line: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "message.badge.filled.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.orbitSeafoam)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ask \(invite.displayName) to text “hi” to \(line)")
                        .font(.orbitHeading(15))
                        .foregroundStyle(Color.textOnDark)
                    Text("That's Ground Control's number for them. The welcome goes out the moment they text.")
                        .font(.orbitBody(12))
                        .foregroundStyle(Color.textOnDarkMuted)
                }
                Spacer(minLength: 0)
            }
            ShareLink(item: "Text “hi” to \(line) to join my Orbit crew — capsules from me will land right in your texts 🚀") {
                Label("Send them the number", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(OrbitPillButtonStyle(color: .orbitSeafoam, textColor: .spaceDeep))
        }
        .padding(16)
        .orbitCard()
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Group {
                if invite.status == .pending {
                    ProgressView().tint(Color.orbitSeafoam)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orbitGold)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(invite.status == .pending ? "Texting \(invite.displayName)…" : "Couldn't text \(invite.displayName)")
                    .font(.orbitHeading(15))
                    .foregroundStyle(Color.textOnDark)
                Text(invite.status == .pending
                     ? "Ground Control is sending the invite to \(invite.phone)."
                     : (invite.error ?? "Is the Orbit agent running? (agent/README.md)"))
                    .font(.orbitBody(12))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .orbitCard()
    }
}
