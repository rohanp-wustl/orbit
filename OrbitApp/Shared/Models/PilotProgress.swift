import Foundation

/// The gamification layer: XP, level, rank, and achievements — all derived
/// from data the app already has (capsules + crew links), so there's no
/// extra table to keep in sync and it's identical on every device.
struct PilotProgress: Equatable {
    static let xpPerLaunch = 50
    static let xpPerUnboxing = 30
    static let xpPerCrewMember = 100
    static let xpPerLevel = 250

    let launched: Int
    let unboxed: Int
    let crewCount: Int

    var xp: Int {
        launched * Self.xpPerLaunch + unboxed * Self.xpPerUnboxing + crewCount * Self.xpPerCrewMember
    }
    var level: Int { xp / Self.xpPerLevel + 1 }
    /// 0...1 progress through the current level, for the XP bar.
    var levelProgress: Double { Double(xp % Self.xpPerLevel) / Double(Self.xpPerLevel) }
    var xpToNextLevel: Int { Self.xpPerLevel - xp % Self.xpPerLevel }

    private static let ranks = ["Cadet", "Pilot", "Navigator", "Commander", "Captain", "Admiral", "Legend"]
    var rank: String { Self.ranks[min(level - 1, Self.ranks.count - 1)] }

    var achievements: [Achievement] {
        [
            Achievement(id: "first_launch", title: "Liftoff", detail: "Launch your first capsule",
                        symbol: "paperplane.fill", hue: .ember, unlocked: launched >= 1),
            Achievement(id: "first_crew", title: "Crew Assembled", detail: "Add someone to your crew",
                        symbol: "person.2.fill", hue: .seafoam, unlocked: crewCount >= 1),
            Achievement(id: "first_unbox", title: "Special Delivery", detail: "Unbox a capsule",
                        symbol: "gift.fill", hue: .magenta, unlocked: unboxed >= 1),
            Achievement(id: "five_launches", title: "Frequent Flyer", detail: "Launch 5 capsules",
                        symbol: "airplane", hue: .violet, unlocked: launched >= 5),
            Achievement(id: "full_crew", title: "Full Crew", detail: "Have 3 crew members",
                        symbol: "person.3.fill", hue: .gold, unlocked: crewCount >= 3),
            Achievement(id: "five_unboxed", title: "Star Collector", detail: "Unbox 5 capsules",
                        symbol: "star.fill", hue: .lime, unlocked: unboxed >= 5),
        ]
    }

    static func from(capsules: [Capsule], crewCount: Int, userId: UUID) -> PilotProgress {
        PilotProgress(
            launched: capsules.filter { $0.senderId == userId && $0.status != .draft }.count,
            unboxed: capsules.filter { $0.recipientId == userId && $0.status == .opened }.count,
            crewCount: crewCount
        )
    }
}

struct Achievement: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let hue: OrbitHue
    let unlocked: Bool
}

/// A "+XP" moment to celebrate on screen (see RewardToast).
struct Reward: Identifiable, Equatable {
    let id = UUID()
    let xp: Int
    let message: String
    /// Set when this reward pushed the pilot into a new level.
    var newLevel: Int? = nil
}
