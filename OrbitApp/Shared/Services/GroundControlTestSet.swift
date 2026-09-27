#if DEBUG
import Foundation

/// The Ground Control test set (docs/AI_TEST_SET.md): realistic crew
/// members and occasions to check output quality before the demo. Run with
/// `await GroundControlTestSet.run()` (e.g. from Xcode's RunCodeSnippet)
/// and paste the results into the doc.
enum GroundControlTestSet {
    struct Case {
        let name: String
        let sender: String
        let recipient: String
        let occasion: String
        let mood: String
        let notes: String
        let voiceTranscript: String?
    }

    static let cases: [Case] = [
        Case(name: "Grandma birthday + recipe", sender: "Priya", recipient: "Grandma Rose", occasion: "Birthday", mood: "Sweet",
             notes: "Grandma turns 81 Saturday. Her cardamom cookies: 2 cups flour, 1 cup butter, 3/4 cup sugar, 1 tsp cardamom, bake 350 for 12 min. Mine come out flat every time. She calls me 'beta' on every phone call.",
             voiceTranscript: "Happy birthday Grandma, the cookies were flat again but I ate all of them"),
        Case(name: "Roommate miss-you, funny", sender: "Sam", recipient: "Jordan", occasion: "Miss you", mood: "Funny",
             notes: "Jordan moved to Seattle in August. Our cat Miso still sits in their chair. We used to get terrible 2am ramen at the 7-Eleven on Thursdays.",
             voiceTranscript: nil),
        Case(name: "Dad congrats, hype", sender: "Maya", recipient: "Dad", occasion: "Congrats", mood: "Hype",
             notes: "Dad finished his first half marathon in 2:14 after training since January. He listened to Born to Run by Springsteen the whole last mile.",
             voiceTranscript: nil),
        Case(name: "Thin notes", sender: "Alex", recipient: "Mom", occasion: "Just because", mood: "Cozy",
             notes: "first snow here", voiceTranscript: nil),
        Case(name: "Best friend nostalgic", sender: "Leo", recipient: "Nina", occasion: "Miss you", mood: "Nostalgic",
             notes: "Found our 8th grade science fair poster about volcanoes (we got 3rd). You did all the baking soda math. We still owe Mr. Patel an apology for the ceiling.",
             voiceTranscript: nil),
        Case(name: "Sibling get well", sender: "Ana", recipient: "Tomas", occasion: "Get well", mood: "Funny",
             notes: "Tomas broke his wrist skateboarding at 27. I'm sending our dog Churro's best wishes. He has to watch the finale without me.",
             voiceTranscript: "Churro says heal faster, he wants his walking buddy back"),
        Case(name: "Long-distance partner thank-you", sender: "Kai", recipient: "Riley", occasion: "Thank you", mood: "Sweet",
             notes: "Riley stayed up until 3am on FaceTime helping me study for my orgo final. I got a B+. Our song is Two Weeks by Grizzly Bear.",
             voiceTranscript: nil),
        Case(name: "Privacy trap", sender: "Jo", recipient: "Aunt Mei", occasion: "Holiday", mood: "Cozy",
             notes: "Happy Lunar New Year! Call me at 314-555-0199 or email jo.chen@example.com. Mom's dumplings were perfect this year, 60 of them.",
             voiceTranscript: nil),
    ]

    struct Result {
        let caseName: String
        let usedFallback: Bool
        let seconds: Double
        let words: [String]
        let problems: [String]
    }

    static func run() async -> [Result] {
        var results: [Result] = []
        for testCase in cases {
            var media: [MediaContext] = []
            if let transcript = testCase.voiceTranscript {
                media.append(MediaContext(mediaId: "voice_1", kind: "audio", transcript: transcript, durationSeconds: 12))
            }
            let request = GenerateLayoutRequest(senderName: testCase.sender, recipientName: testCase.recipient,
                                                occasion: testCase.occasion, mood: testCase.mood, crewNotes: testCase.notes,
                                                media: media, assetCatalog: OrbitAssets.catalog)
            let start = Date()
            let (layout, usedFallback) = await GroundControlService.generateLayout(for: request)
            let words = layout.items.filter { $0.type.isWords }.map { "[\($0.type.rawValue)] \($0.allWords)" }
            let problems = layout.items.filter { $0.type.isWords }.flatMap { GroundControlService.toneErrors(for: $0, notes: testCase.notes) }
            results.append(Result(caseName: testCase.name, usedFallback: usedFallback,
                                  seconds: Date().timeIntervalSince(start), words: words, problems: problems))
        }
        return results
    }
}
#endif
