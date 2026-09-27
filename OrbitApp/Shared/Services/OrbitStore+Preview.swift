import Foundation

extension OrbitStore {
    /// The seeded demo crew (docs/DEMO_GUIDE.md): Grandma Rose, Maya, and
    /// Jordan, with capsules in every state. Powers Offline demo mode
    /// (Settings → About) — the backup if venue Wi-Fi dies — and previews.
    /// Never touches the network.
    static func demo(for me: AppUser) -> OrbitStore {
        let grandma = AppUser(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A001") ?? UUID(), displayName: "Grandma Rose")
        let maya = AppUser(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A002") ?? UUID(), displayName: "Maya")
        let jordan = AppUser(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A003") ?? UUID(), displayName: "Jordan")
        let store = OrbitStore(currentUser: me, isDemo: true)

        let crew = [grandma, maya, jordan]
        let links = crew.map { CrewLink(userA: me.id, userB: $0.id, inviteCode: "SEED\($0.displayName.prefix(2).uppercased())") }
        store.crewLinks = links
        store.profiles = Dictionary(uniqueKeysWithValues: crew.map { ($0.id, $0) })

        let now = Date()
        let fromGrandma = CapsuleLayout(background: "kraft_paper_02", template: "polaroid_scatter", items: [
            LayoutItem(id: "g1", type: .letter, text: "The tomatoes came in early this year, so I made your favorite sauce and froze a jar for when you visit. Your grandfather would have eaten it straight from the pot.",
                       font: "handwritten", x: 0.5, y: 0.22, w: 0.84, rotation: -2, z: 1),
            LayoutItem(id: "g2", type: .recipe, title: "Grandma's Sunday Sauce",
                       lines: ["8 ripe tomatoes", "4 cloves garlic", "Basil from the window box", "Simmer 3 hours, stir when you walk by"],
                       x: 0.3, y: 0.58, w: 0.5, rotation: -4, z: 2),
            LayoutItem(id: "g3", type: .song, title: "Moon River", artist: "Andy Williams", x: 0.68, y: 0.5, w: 0.56, rotation: 3, z: 3),
            LayoutItem(id: "g4", type: .question, text: "When are you coming home to eat it?", font: "marker",
                       x: 0.62, y: 0.82, w: 0.62, rotation: 2, z: 4),
            LayoutItem(id: "g5", type: .sticker, asset: "heart", x: 0.88, y: 0.66, w: 0.12, rotation: 12, z: 5),
            LayoutItem(id: "g6", type: .sticker, asset: "sun", x: 0.12, y: 0.86, w: 0.14, rotation: -8, z: 6),
        ], packageColor: OrbitHue.gold.rawValue)

        let fromMaya = CapsuleLayout(background: "night_sky", template: "single_hero", items: [
            LayoutItem(id: "m1", type: .text, text: "Finals are over. I slept 14 hours.", font: "handwritten", x: 0.5, y: 0.4, w: 0.8, z: 1),
            LayoutItem(id: "m2", type: .question, text: "Movie night when you're back?", font: "marker", x: 0.5, y: 0.66, w: 0.7, z: 2),
            LayoutItem(id: "m3", type: .sticker, asset: "moon", x: 0.84, y: 0.14, w: 0.16, z: 3),
        ], packageColor: OrbitHue.violet.rawValue)

        let toJordan = CapsuleLayout(background: "mint_grid", template: "scrapbook_collage", items: [
            LayoutItem(id: "j1", type: .text, text: "Miso is still holding your chair. She wants rent.", font: "handwritten", x: 0.5, y: 0.35, w: 0.8, rotation: -3, z: 1),
            LayoutItem(id: "j2", type: .sticker, asset: "paw", x: 0.3, y: 0.6, w: 0.2, rotation: -10, z: 2),
            LayoutItem(id: "j3", type: .sticker, asset: "coffee", x: 0.7, y: 0.64, w: 0.18, rotation: 12, z: 3),
        ], packageColor: OrbitHue.seafoam.rawValue)

        let oldFromJordan = CapsuleLayout(background: "sunset_wash", template: "clean_grid", items: [
            LayoutItem(id: "o1", type: .text, text: "Seattle 7-Eleven ramen: 6/10. Missing our Thursday one.", font: "marker", x: 0.5, y: 0.4, w: 0.84, z: 1),
            LayoutItem(id: "o2", type: .sticker, asset: "rocket", x: 0.5, y: 0.66, w: 0.2, z: 2),
        ], packageColor: OrbitHue.ember.rawValue)

        store.capsules = [
            Capsule(senderId: grandma.id, recipientId: me.id, crewLinkId: links[0].id, status: .landed,
                    layout: fromGrandma, createdAt: now.addingTimeInterval(-300),
                    launchedAt: now.addingTimeInterval(-300), deliveryAt: now.addingTimeInterval(-240), deliveryDelaySeconds: 60),
            Capsule(senderId: maya.id, recipientId: me.id, crewLinkId: links[1].id, status: .launched,
                    layout: fromMaya, createdAt: now, launchedAt: now.addingTimeInterval(-5),
                    deliveryAt: now.addingTimeInterval(25), deliveryDelaySeconds: 30),
            Capsule(senderId: me.id, recipientId: jordan.id, crewLinkId: links[2].id, status: .opened,
                    layout: toJordan, createdAt: now.addingTimeInterval(-86_400 * 2),
                    launchedAt: now.addingTimeInterval(-86_400 * 2), deliveryAt: now.addingTimeInterval(-86_400 * 2 + 10)),
            Capsule(senderId: jordan.id, recipientId: me.id, crewLinkId: links[2].id, status: .opened,
                    layout: oldFromJordan, createdAt: now.addingTimeInterval(-86_400 * 9),
                    launchedAt: now.addingTimeInterval(-86_400 * 9), deliveryAt: now.addingTimeInterval(-86_400 * 9 + 10),
                    openedAt: now.addingTimeInterval(-86_400 * 9 + 60)),
        ]
        return store
    }

    #if DEBUG
    /// Sample session for SwiftUI previews.
    static var preview: OrbitStore { demo(for: AppUser(id: UUID(), displayName: "Rohan")) }
    #endif
}
