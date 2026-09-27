import SwiftUI

/// The archive (docs decision: yes, it looks like a scrapbook). Every
/// capsule you've opened becomes a taped-in page, newest first; a toggle
/// shows the ones you sent too. Tap a page to see it full size.
struct ScrapbookView: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showSent = false

    private var pages: [Capsule] {
        store.capsules
            .filter { showSent ? ($0.senderId == store.currentUser.id) : ($0.recipientId == store.currentUser.id && $0.status == .opened) }
            .sorted { ($0.openedAt ?? $0.createdAt) > ($1.openedAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Pages", selection: $showSent) {
                        Text("Received").tag(false)
                        Text("Sent").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    if pages.isEmpty {
                        VStack(spacing: 14) {
                            CosmoView(size: 110, pose: .sleep)
                            Text(showSent ? "Nothing sent yet." : "Open a capsule and it gets taped in here.")
                                .font(.orbitBody(15))
                                .foregroundStyle(Color.inkBrown)
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)], spacing: 26) {
                            ForEach(Array(pages.enumerated()), id: \.element.id) { index, capsule in
                                Button {
                                    dismiss()
                                    store.presentedCapsule = capsule
                                } label: {
                                    ScrapbookPage(capsule: capsule, index: index,
                                                  title: showSent ? "To \(store.name(for: capsule.recipientId))"
                                                                  : "From \(store.name(for: capsule.senderId))")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color.kraftPaper.ignoresSafeArea())
            .navigationTitle("Scrapbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.light)
    }
}

/// One taped-in page: a mini render of the capsule, slightly askew.
private struct ScrapbookPage: View {
    let capsule: Capsule
    let index: Int
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            CapsulePageView(layout: capsule.layout, senderId: capsule.senderId)
                .allowsHitTesting(false)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.skyGlass.opacity(0.55))
                        .frame(width: 56, height: 16)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -6 : 5))
                        .offset(y: -6)
                }
            Text(title)
                .font(.orbitHandwritten(20))
                .foregroundStyle(Color.inkBrown)
            Text((capsule.openedAt ?? capsule.createdAt).formatted(date: .abbreviated, time: .omitted))
                .font(.orbitBody(11))
                .foregroundStyle(Color.inkBrown.opacity(0.7))
        }
        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -2.5 : 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \((capsule.openedAt ?? capsule.createdAt).formatted(date: .abbreviated, time: .omitted))")
    }
}

#Preview {
    ScrapbookView()
        .environment(OrbitStore.preview)
}
