// DEFERRED for the free-tier MVP: a free Apple ID's "Personal Team" can't
// sign the App Groups entitlement this widget needs to read live state from
// the app (see docs/PUSH_AND_WIDGET_PLAN.md). Don't add this as a target in
// Xcode yet — build InAppWidgetPreviewView instead, which shows the same
// thing inside the app. Come back to this file once there's a paid account.

import WidgetKit
import SwiftUI

struct CapsuleWidgetEntry: TimelineEntry {
    let date: Date
    let status: CapsuleStatus?
    let senderName: String?
}

/// Deliberately does NOT hit Firestore from inside the widget extension —
/// widgets have a tight execution budget and Apple's own guidance is to keep
/// extensions fast and network-free where possible. Instead, the main app
/// writes the latest known state into the shared App Group container
/// whenever it changes, and this just reads that. See
/// docs/PUSH_AND_WIDGET_PLAN.md for the full push → app → widget chain.
struct CapsuleTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CapsuleWidgetEntry {
        CapsuleWidgetEntry(date: Date(), status: .inTransit, senderName: "Someone")
    }

    func getSnapshot(in context: Context, completion: @escaping (CapsuleWidgetEntry) -> Void) {
        completion(readLatestEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CapsuleWidgetEntry>) -> Void) {
        // A single entry with `.never` is correct here: refresh is driven by
        // WidgetCenter.shared.reloadTimelines(ofKind:), called by the app
        // when it receives a background push — not by WidgetKit's own
        // timeline schedule. Widget refresh budgets are limited and not
        // meant for "poll every few minutes" use cases.
        completion(Timeline(entries: [readLatestEntry()], policy: .never))
    }

    private func readLatestEntry() -> CapsuleWidgetEntry {
        // TODO: replace "group.com.yourteam.orbit" with your real App Group
        // identifier once created — must match Entitlements/*.entitlements.
        guard let defaults = UserDefaults(suiteName: "group.com.yourteam.orbit"),
              let statusRaw = defaults.string(forKey: "latestCapsule.status") else {
            return CapsuleWidgetEntry(date: Date(), status: nil, senderName: nil)
        }
        return CapsuleWidgetEntry(
            date: Date(),
            status: CapsuleStatus(rawValue: statusRaw),
            senderName: defaults.string(forKey: "latestCapsule.senderName")
        )
    }
}

struct OrbitWidgetView: View {
    let entry: CapsuleWidgetEntry

    var body: some View {
        switch entry.status {
        case .none, .some(.draft), .some(.opened):
            labeled(systemImage: "moon.stars.fill", text: "No capsules in transit")
        case .some(.launched), .some(.inTransit):
            // Lock screen renders this monochrome ("vibrant" mode) — keep it
            // to a bold icon + a few words so it still reads there.
            labeled(systemImage: "airplane", text: entry.senderName.map { "From \($0)" } ?? "Incoming")
        case .some(.landed):
            labeled(systemImage: "gift.fill", text: "Landed — tap to open")
        }
    }

    private func labeled(systemImage: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text).font(.caption2)
        }
    }
}

struct OrbitWidget: Widget {
    let kind = "OrbitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CapsuleTimelineProvider()) { entry in
            OrbitWidgetView(entry: entry)
        }
        .configurationDisplayName("Orbit")
        .description("See when a capsule from your crew is about to land.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        // TODO Phase 4: add `.widgetURL(...)` so tapping opens straight to
        // UnboxingView when status == .landed.
    }
}

#Preview(as: .systemSmall) {
    OrbitWidget()
} timeline: {
    CapsuleWidgetEntry(date: .now, status: .inTransit, senderName: "Mia")
    CapsuleWidgetEntry(date: .now, status: .landed, senderName: "Mia")
}
