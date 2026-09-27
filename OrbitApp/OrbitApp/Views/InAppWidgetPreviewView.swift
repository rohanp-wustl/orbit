import SwiftUI

/// Stands in for the real home-screen widget until there's a paid Apple
/// Developer account to sign the App Groups entitlement (see
/// docs/PUSH_AND_WIDGET_PLAN.md). Styled like a widget: the newest
/// capsule headed to you, its package, and a live countdown — driven by
/// the same Realtime state as the rest of Home.
struct InAppWidgetPreviewView: View {
    let latestCapsule: Capsule?
    var senderName: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 16) {
                illustration(now: context.date)
                    .frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MISSION STATUS")
                        .font(.orbitHeading(10))
                        .tracking(1.5)
                        .foregroundStyle(Color.skyGlass)
                    Text(title(now: context.date))
                        .font(.orbitHeading(17))
                        .foregroundStyle(Color.textOnDark)
                    Text(subtitle(now: context.date))
                        .font(.orbitBody(13))
                        .foregroundStyle(Color.textOnDarkMuted)
                        .contentTransition(.numericText(countsDown: true))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .orbitCard(fill: .panelNavy, cornerRadius: 26)
        }
        .accessibilityElement(children: .combine)
    }

    private func isLanded(now: Date) -> Bool {
        guard let capsule = latestCapsule else { return false }
        return capsule.status == .landed || (capsule.deliveryAt ?? .distantPast) <= now
    }

    @ViewBuilder
    private func illustration(now: Date) -> some View {
        if let capsule = latestCapsule {
            if isLanded(now: now) {
                GiftBoxView(hue: OrbitHue.named(capsule.layout.packageColor).color, size: 52)
                    .phaseAnimator([0.0, -6, 6, 0]) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } animation: { _ in .easeInOut(duration: 0.25) }
            } else {
                let hue = OrbitHue.named(capsule.layout.packageColor).color
                RocketView(height: 68, thrust: 0.6, hue: hue, cargo: hue)
            }
        } else {
            ShadedPlanet(hue: .accentBlue, size: 48, spinSpeed: 0.2)
        }
    }

    private func title(now: Date) -> String {
        guard latestCapsule != nil else { return "All quiet in orbit" }
        let name = senderName ?? "Your crew"
        return isLanded(now: now) ? "\(name)'s capsule landed!" : "Incoming from \(name)"
    }

    private func subtitle(now: Date) -> String {
        guard let capsule = latestCapsule else { return "Packages from your crew land here." }
        if isLanded(now: now) { return "Tap to open it" }
        let seconds = max(0, Int((capsule.deliveryAt ?? now).timeIntervalSince(now).rounded(.up)))
        return "Rocket lands in \(LaunchView.duration(seconds))"
    }
}

#Preview {
    ZStack {
        Color.spaceDeep.ignoresSafeArea()
        InAppWidgetPreviewView(latestCapsule: nil).padding()
    }
}
