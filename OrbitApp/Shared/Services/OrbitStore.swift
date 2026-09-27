import Foundation
import Observation
#if canImport(Supabase)
import Supabase
#endif

/// Shared state for every tab: capsules, crew, names, progress, and the
/// live Realtime subscriptions that keep them current. One instance per
/// signed-in session, created by MainTabView and passed via the environment.
@Observable
final class OrbitStore {
    let currentUser: AppUser

    var capsules: [Capsule] = []
    var crewLinks: [CrewLink] = []
    /// Display names for crew members, keyed by user id.
    var profiles: [UUID: AppUser] = [:]
    var loadError: String?
    /// The latest "+XP" moment for RewardToast to show; nil when idle.
    var reward: Reward?

    // Navigation shared across tabs (e.g. Galaxy's "Send to Maya" jumps to
    // Create with Maya picked; Home's packages open full-screen).
    var selectedTab: OrbitTab = .home
    var presentedCapsule: Capsule?
    var preselectedRecipient: UUID?

    #if canImport(Supabase)
    @ObservationIgnored private var capsuleChannel: RealtimeChannelV2?
    @ObservationIgnored private var crewChannel: RealtimeChannelV2?
    #endif

    /// Offline demo (Settings → About → Offline demo mode): a seeded crew
    /// including Grandma, no network at all — the backup plan if venue
    /// Wi-Fi dies mid-demo. Launches, landings, and unboxings all run locally.
    let isDemo: Bool

    init(currentUser: AppUser, isDemo: Bool = false) {
        self.currentUser = currentUser
        self.isDemo = isDemo
    }

    /// Inserts a launched capsule (skipped in offline demo mode).
    func send(_ capsule: Capsule) async throws {
        guard !isDemo else { return }
        #if canImport(Supabase)
        try await CapsuleRepository.shared.createCapsule(capsule)
        #endif
    }

    // MARK: - Derived

    var joinedLinks: [CrewLink] { crewLinks.filter { !$0.isPending } }
    var pendingInvites: [CrewLink] { crewLinks.filter(\.isPending) }

    /// Crew members (the other person on each joined link).
    var crewMembers: [AppUser] {
        joinedLinks.compactMap { link in
            link.otherUserId(than: currentUser.id).map { id in
                profiles[id] ?? AppUser(id: id, displayName: "Crew member")
            }
        }
    }

    /// Sent to me and not yet opened — packages waiting on the launchpad.
    var incoming: [Capsule] {
        capsules.filter { $0.recipientId == currentUser.id && $0.status != .opened }
    }

    /// Sent by me and still traveling.
    var outgoingInFlight: [Capsule] {
        capsules.filter { $0.senderId == currentUser.id && ($0.status == .launched || $0.status == .inTransit) }
    }

    var progress: PilotProgress {
        PilotProgress.from(capsules: capsules, crewCount: joinedLinks.count, userId: currentUser.id)
    }

    func name(for userId: UUID) -> String {
        userId == currentUser.id ? currentUser.displayName : (profiles[userId]?.displayName ?? "Crew member")
    }

    /// The other person on a capsule, from my point of view.
    func otherPerson(on capsule: Capsule) -> UUID {
        capsule.senderId == currentUser.id ? capsule.recipientId : capsule.senderId
    }

    func link(with userId: UUID) -> CrewLink? {
        joinedLinks.first { $0.otherUserId(than: currentUser.id) == userId }
    }

    // MARK: - Loading

    /// Loads once, then subscribes for the life of the session. A one-time
    /// fetch alongside the subscription means a missed Realtime event heals
    /// on the next reload (docs/RISKS_AND_FALLBACKS.md).
    func start() async {
        guard !isDemo else { return }
        await reload()
        #if canImport(Supabase)
        guard capsuleChannel == nil else { return }
        capsuleChannel = CapsuleRepository.shared.subscribeToCapsules(involvingUserId: currentUser.id) { [weak self] updated in
            Task { @MainActor in
                self?.capsules = updated
                await self?.scheduleLandingNotifications()
            }
        }
        crewChannel = CrewRepository.shared.subscribeToCrewLinks(for: currentUser.id) { [weak self] updated in
            Task { @MainActor in
                guard let self else { return }
                let before = self.joinedLinks.count
                let levelBefore = self.progress.level
                self.crewLinks = updated
                await self.loadProfiles()
                // Someone joined my invite code — that's a reward moment too.
                if self.joinedLinks.count > before {
                    self.celebrate(xp: PilotProgress.xpPerCrewMember, "New crew member!", levelBefore: levelBefore)
                }
            }
        }
        #endif
    }

    func reload() async {
        guard !isDemo else { return }
        #if canImport(Supabase)
        do {
            async let fetchedCapsules = CapsuleRepository.shared.fetchCapsules(involvingUserId: currentUser.id)
            async let fetchedLinks = CrewRepository.shared.fetchCrewLinks(for: currentUser.id)
            (capsules, crewLinks) = try await (fetchedCapsules, fetchedLinks)
            await loadProfiles()
            loadError = nil
            await scheduleLandingNotifications()
        } catch {
            loadError = "Couldn't reach Ground Control. Pull to retry. (\(error.localizedDescription))"
        }
        #endif
    }

    private func loadProfiles() async {
        #if canImport(Supabase)
        let ids = Set(joinedLinks.compactMap { $0.otherUserId(than: currentUser.id) })
        if let fetched = try? await CrewRepository.shared.fetchProfiles(ids: Array(ids)) {
            profiles = fetched
        }
        #endif
    }

    // MARK: - Actions

    func createInvite() async throws -> CrewLink {
        if isDemo {
            let link = CrewLink(userA: currentUser.id, inviteCode: "DEMO42")
            crewLinks.insert(link, at: 0)
            return link
        }
        #if canImport(Supabase)
        let link = try await CrewRepository.shared.createInvite(for: currentUser.id)
        crewLinks.insert(link, at: 0)
        return link
        #else
        throw CancellationError()
        #endif
    }

    // MARK: - iMessage crew (docs/PHOTON.md)

    /// Recent "invite by iMessage" requests and their status (pending → sent/failed).
    var imessageInvites: [IMessageInvite] = []

    /// Asks Ground Control to text someone an invite. Polls for the agent's
    /// answer for up to a minute; on success the new crew link arrives through
    /// the crew Realtime subscription like any other join.
    func inviteByIMessage(name: String, phone: String) async throws {
        guard !isDemo else { return }
        #if canImport(Supabase)
        let invite = try await CrewRepository.shared.inviteByIMessage(
            name: name, phone: IMessageInvite.normalize(phone), inviterId: currentUser.id)
        imessageInvites.insert(invite, at: 0)
        for _ in 0..<20 {
            try? await Task.sleep(for: .seconds(3))
            await refreshIMessageInvites()
            if imessageInvites.first(where: { $0.id == invite.id })?.status != .pending { break }
        }
        // Waiting on them to text their Ground Control line once (Photon shared
        // lines). Keep checking for up to 10 minutes so the celebration lands
        // the moment they do; the Galaxy card shows the number meanwhile.
        var checks = 0
        while checks < 120, imessageInvites.first(where: { $0.id == invite.id })?.status == .waiting {
            try? await Task.sleep(for: .seconds(5))
            await refreshIMessageInvites()
            checks += 1
        }
        if imessageInvites.first(where: { $0.id == invite.id })?.status == .sent {
            let levelBefore = progress.level
            await reload()
            celebrate(xp: PilotProgress.xpPerCrewMember, "\(name) joined via iMessage!", levelBefore: levelBefore)
        }
        #endif
    }

    func refreshIMessageInvites() async {
        guard !isDemo else { return }
        #if canImport(Supabase)
        if let invites = try? await CrewRepository.shared.fetchIMessageInvites(for: currentUser.id) {
            imessageInvites = invites
        }
        #endif
    }

    /// Returns false when the code is wrong, used, or your own.
    func join(code: String) async throws -> Bool {
        guard !isDemo else { return false }
        #if canImport(Supabase)
        let levelBefore = progress.level
        guard try await CrewRepository.shared.joinCrew(code: code) != nil else { return false }
        await reload()
        celebrate(xp: PilotProgress.xpPerCrewMember, "Crew member added!", levelBefore: levelBefore)
        return true
        #else
        return false
        #endif
    }

    /// Called after ComposeCapsuleView inserts the row, so the reward and
    /// the launchpad update instantly instead of waiting on Realtime.
    func didLaunch(_ capsule: Capsule) {
        let levelBefore = progress.level
        if !capsules.contains(where: { $0.id == capsule.id }) {
            capsules.insert(capsule, at: 0)
        }
        celebrate(xp: PilotProgress.xpPerLaunch, "Capsule launched!", levelBefore: levelBefore)
        let recipientName = name(for: capsule.recipientId)
        Task { await LandingNotifications.scheduleDelivered(capsule, to: recipientName) }
    }

    /// Recipient side: a local "capsule landed" notification for every
    /// rocket still inbound (see LandingNotifications).
    func scheduleLandingNotifications() async {
        for capsule in incoming where capsule.status == .launched || capsule.status == .inTransit {
            await LandingNotifications.scheduleArrival(of: capsule, from: name(for: capsule.senderId))
        }
    }

    func markOpened(_ capsule: Capsule) async {
        LandingNotifications.cancel(for: capsule)
        let levelBefore = progress.level
        if let index = capsules.firstIndex(where: { $0.id == capsule.id }) {
            capsules[index].status = .opened
            capsules[index].openedAt = Date()
        }
        celebrate(xp: PilotProgress.xpPerUnboxing, "Capsule unboxed!", levelBefore: levelBefore)
        guard !isDemo else { return }
        #if canImport(Supabase)
        try? await CapsuleRepository.shared.updateStatus(capsuleId: capsule.id, to: .opened, timestampColumn: "opened_at")
        #endif
    }

    /// Recipient side: flips launched capsules to .landed once deliveryAt
    /// passes, so both phones update via Realtime. Only the recipient does
    /// this, so two phones never race on the same row.
    func markLandedWhenDue() async {
        #if canImport(Supabase)
        let due = incoming
            .filter { $0.status == .launched || $0.status == .inTransit }
            .sorted { ($0.deliveryAt ?? .distantPast) < ($1.deliveryAt ?? .distantPast) }
        for capsule in due {
            let wait = (capsule.deliveryAt ?? .now).timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            if let index = capsules.firstIndex(where: { $0.id == capsule.id }), capsules[index].status != .opened {
                capsules[index].status = .landed
            }
            guard !isDemo else { continue }
            try? await CapsuleRepository.shared.updateStatus(capsuleId: capsule.id, to: .landed)
        }
        #endif
    }

    private func celebrate(xp: Int, _ message: String, levelBefore: Int?) {
        let levelAfter = progress.level
        var newReward = Reward(xp: xp, message: message)
        if let levelBefore, levelAfter > levelBefore {
            newReward.newLevel = levelAfter
        }
        reward = newReward
    }
}
