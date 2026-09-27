import SwiftUI

/// What opens when you tap a capsule anywhere in the app.
/// - Sent to me and not yet opened → the full PackageOpeningView unboxing.
/// - Otherwise (I sent it, or it's already opened) → the finished
///   scrapbook page with its live delivery status.
struct CapsuleDetailView: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Snapshot at presentation — decides the route once, so the view
    /// doesn't flip to the viewer mid-unboxing when the status updates.
    let capsule: Capsule

    private var isRecipient: Bool { capsule.recipientId == store.currentUser.id }
    /// Latest copy from the store, so the sender sees status change live.
    private var live: Capsule { store.capsules.first { $0.id == capsule.id } ?? capsule }
    private var otherName: String { store.name(for: store.otherPerson(on: capsule)) }

    var body: some View {
        Group {
            if isRecipient && capsule.status != .opened {
                PackageOpeningView(capsule: capsule, senderName: otherName,
                                   onOpened: { Task { await store.markOpened(capsule) } },
                                   onClose: { dismiss() },
                                   onReply: reply)
            } else {
                viewer
            }
        }
        .preferredColorScheme(.dark)
    }

    private var viewer: some View {
        ZStack {
            StarfieldBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.textOnDark)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.panelNavy))
                        }
                        .accessibilityLabel("Close")
                        Spacer()
                    }

                    HStack(spacing: 14) {
                        GiftBoxView(hue: OrbitHue.named(live.layout.packageColor).color, size: 44, showsShadow: false)
                            .frame(width: 52, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isRecipient ? "From \(otherName)" : "To \(otherName)")
                                .font(.orbitDisplay(24))
                                .foregroundStyle(Color.textOnDark)
                            Text(live.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.orbitBody(13))
                                .foregroundStyle(Color.textOnDarkMuted)
                        }
                        Spacer()
                    }

                    CapsulePageView(layout: live.layout, senderId: live.senderId)

                    statusChip

                    if isRecipient {
                        Button(action: reply) {
                            Label("Send \(otherName) one back", systemImage: "arrowshape.turn.up.left.fill")
                        }
                        .buttonStyle(OrbitPillButtonStyle())
                    }
                }
                .padding(20)
            }
        }
    }

    /// Reply capsule: Create opens with the sender already picked.
    private func reply() {
        store.preselectedRecipient = capsule.senderId
        store.selectedTab = .create
        dismiss()
    }

    private var statusChip: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let (text, symbol, color) = status(now: context.date)
            Label(text, systemImage: symbol)
                .font(.orbitHeading(14))
                .foregroundStyle(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(SwiftUI.Capsule().fill(Color.panelNavy))
                .contentTransition(.numericText(countsDown: true))
        }
    }

    private func status(now: Date) -> (String, String, Color) {
        if isRecipient { return ("Unboxed", "checkmark.seal.fill", .orbitSeafoam) }
        switch live.status {
        case .draft:
            return ("Draft", "pencil", .textOnDarkMuted)
        case .launched, .inTransit:
            let seconds = max(0, Int((live.deliveryAt ?? now).timeIntervalSince(now).rounded(.up)))
            return seconds > 0 ? ("In orbit · lands in \(seconds)s", "airplane", .skyGlass)
                               : ("Landing…", "airplane.arrival", .skyGlass)
        case .landed:
            return ("Landed · waiting for \(otherName) to open it", "shippingbox.fill", .orbitGold)
        case .opened:
            return ("Opened by \(otherName)", "checkmark.seal.fill", .orbitSeafoam)
        }
    }
}
