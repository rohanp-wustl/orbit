import SwiftUI

/// Full-screen flow after tapping "Pack & launch" (or "build it myself"):
/// packing (upload + Ground Control) → editing (canvas + Ground Control's
/// drafts as editable cards) → the launch journey → back to Home.
struct LaunchFlowView: View {
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let draft: CapsuleDraft

    private enum Step { case packing, editing, launching }

    @State private var step: Step = .packing
    @State private var layout = CapsuleLayout(background: "kraft_paper_02", template: "polaroid_scatter", items: [])
    @State private var request: GenerateLayoutRequest?
    @State private var usedFallback = false
    @State private var launchedCapsule: Capsule?
    @State private var isLaunching = false
    @State private var errorMessage: String?
    @State private var editingItemId: String?
    @State private var redoingItemId: String?
    @State private var aiTask: Task<(layout: CapsuleLayout, usedFallback: Bool), Never>?

    private var recipientName: String {
        draft.recipientId.map { store.name(for: $0) } ?? "your crew"
    }

    /// Ground Control's words still in the capsule, shown as cards.
    private var draftedItems: [LayoutItem] {
        layout.items.filter { $0.type.isWords && $0.aiDrafted }
    }

    var body: some View {
        ZStack {
            switch step {
            case .packing:
                GroundControlLoadingView(recipientName: recipientName, onSkip: { aiTask?.cancel() })
                    .transition(.opacity)
            case .editing:
                editor
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .launching:
                if let launchedCapsule {
                    LaunchView(capsule: launchedCapsule, recipientName: recipientName) { finish(launchedCapsule) }
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .task { await pack() }
        .sheet(item: Binding(get: { editingItemId.map(IdentifiedString.init) }, set: { editingItemId = $0?.value })) { wrapped in
            if let index = layout.items.firstIndex(where: { $0.id == wrapped.value }) {
                ItemEditorSheet(item: $layout.items[index])
            }
        }
    }

    // MARK: - Editor step

    private var editor: some View {
        NavigationStack {
            ZStack {
                StarfieldBackground(base: .panelNavy, starCount: 25)
                ScrollView {
                    VStack(spacing: 12) {
                        Text(editorHint)
                            .font(.orbitBody(13))
                            .foregroundStyle(Color.textOnDarkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        CapsuleEditorView(layout: $layout, senderId: store.currentUser.id)
                            .tint(.skyGlass)

                        if !draftedItems.isEmpty { draftCards }

                        if let errorMessage {
                            Text(errorMessage).font(.orbitBody(12)).foregroundStyle(Color.orbitEmber)
                        }

                        Button {
                            Task { await launch() }
                        } label: {
                            Label(isLaunching ? "Fueling…" : "Launch to \(recipientName)", systemImage: "flame.fill")
                        }
                        .buttonStyle(OrbitPillButtonStyle(color: .orbitEmber))
                        .disabled(layout.items.isEmpty || isLaunching)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle(draft.buildItMyself ? "Build your page" : "Arrange your package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var editorHint: String {
        if draft.buildItMyself { return "Your media is on a plain template. Add words and stickers below, then drag, pinch, and twist." }
        if usedFallback { return "Ground Control couldn't reach orbit, so here's a simple start. Make it yours!" }
        return "Drag, pinch, and twist. Ground Control's drafts are below — keep, edit, redo, or remove each one."
    }

    /// Ground Control's suggestions as editable cards (docs/AI_SPEC.md "UI"):
    /// never a chat, never regenerating the whole capsule — one item at a time.
    private var draftCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GROUND CONTROL'S DRAFTS")
                .font(.orbitHeading(11))
                .tracking(1.5)
                .foregroundStyle(Color.skyGlass)
                .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(draftedItems) { item in
                        DraftCard(item: item, isRedoing: redoingItemId == item.id,
                                  onEdit: { editingItemId = item.id },
                                  onRedo: { Task { await redo(item) } },
                                  onRemove: { withAnimation(.spring) { layout.items.removeAll { $0.id == item.id } } })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Actions

    private func pack() async {
        #if canImport(Supabase)
        let senderId = store.currentUser.id
        if store.isDemo {
            // Offline demo: keep everything on the phone.
            for photo in draft.photos { MediaRepository.shared.remember(image: photo.image, for: photo.mediaId) }
            for note in draft.voiceNotes { MediaRepository.shared.remember(file: note.fileURL, for: note.mediaId) }
        } else { do {
            for photo in draft.photos {
                try await MediaRepository.shared.upload(photo, senderId: senderId)
            }
            for note in draft.voiceNotes {
                try await MediaRepository.shared.uploadFile(at: note.fileURL, mediaId: note.mediaId, type: .audio,
                                                            senderId: senderId, transcript: note.transcript)
            }
            if let video = draft.video {
                try await MediaRepository.shared.uploadFile(at: video.fileURL, mediaId: video.mediaId, type: .video, senderId: senderId)
            }
        } catch {
            draft.errorMessage = "Couldn't upload your media. Has docs/STAGE3_MIGRATION.sql been run? (\(error.localizedDescription))"
            dismiss()
            return
        } }

        var media = draft.photos.map { MediaContext(mediaId: $0.mediaId, kind: "photo", thumbnailBase64: $0.thumbnailBase64) }
        if let video = draft.video {
            media.append(MediaContext(mediaId: video.mediaId, kind: "video", thumbnailBase64: video.posterBase64, durationSeconds: video.duration))
        }
        media += draft.voiceNotes.map { MediaContext(mediaId: $0.mediaId, kind: "audio", transcript: $0.transcript, durationSeconds: $0.duration) }

        let request = GenerateLayoutRequest(
            senderName: store.currentUser.displayName,
            recipientName: recipientName,
            occasion: draft.occasion.rawValue,
            mood: draft.mood.rawValue,
            crewNotes: draft.notes,
            media: media,
            assetCatalog: OrbitAssets.catalog
        )
        self.request = request

        if draft.buildItMyself {
            layout = GroundControlService.buildFallbackLayout(for: request)
            try? await Task.sleep(for: .seconds(0.8)) // let the packing beat land
        } else {
            // Cancellable, so "arrange it myself" can cut a slow model short
            // (cancellation aborts the network call → template fallback).
            let task = Task { await GroundControlService.generateLayout(for: request) }
            aiTask = task
            let result = await task.value
            layout = result.layout
            usedFallback = result.usedFallback
        }
        step = .editing
        #endif
    }

    private func redo(_ item: LayoutItem) async {
        guard let request else { return }
        redoingItemId = item.id
        defer { redoingItemId = nil }
        if let rewritten = await GroundControlService.regenerate(item, in: layout, for: request),
           let index = layout.items.firstIndex(where: { $0.id == item.id }) {
            withAnimation(.spring) { layout.items[index] = rewritten }
            SoundFX.play(.tick)
        } else {
            errorMessage = "Ground Control couldn't redo that one — try again or edit it yourself."
        }
    }

    private func launch() async {
        #if canImport(Supabase)
        guard let recipientId = draft.recipientId, let link = store.link(with: recipientId) else { return }
        isLaunching = true
        defer { isLaunching = false }
        errorMessage = nil

        var finalLayout = layout
        finalLayout.packageColor = draft.hue.rawValue
        let now = Date()
        let delay = draft.speed.seconds(from: now)
        let capsuleId = UUID()
        let capsule = Capsule(
            id: capsuleId,
            senderId: store.currentUser.id,
            recipientId: recipientId,
            crewLinkId: link.id,
            status: .launched,
            layout: finalLayout,
            createdAt: now,
            launchedAt: now,
            deliveryAt: now.addingTimeInterval(TimeInterval(delay)),
            deliveryDelaySeconds: delay,
            previewImagePath: draft.photos.first.map { MediaRepository.storagePath(mediaId: $0.mediaId, senderId: store.currentUser.id) }
        )
        var toSend = capsule
        do {
            // Snapshot of the finished page — what Ground Control texts to
            // iMessage recipients (docs/PHOTON.md). Best-effort: a failed
            // snapshot falls back to the first photo.
            if !store.isDemo, let png = renderPageSnapshot(finalLayout),
               let path = try? await MediaRepository.shared.uploadPreview(png, capsuleId: capsuleId, senderId: store.currentUser.id) {
                toSend.previewImagePath = path
            }
            try await store.send(toSend)
            launchedCapsule = toSend
            step = .launching
        } catch {
            errorMessage = "Couldn't launch. (\(error.localizedDescription))"
        }
        #endif
    }

    /// Renders the page at a fixed width as PNG (photos come from the cache
    /// the uploads just filled, so they appear on the first frame).
    private func renderPageSnapshot(_ layout: CapsuleLayout) -> Data? {
        let page = CapsulePageView(layout: layout, senderId: store.currentUser.id)
            .frame(width: 600)
            .padding(24)
            .background(Color.spaceDeep)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: page)
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    private func finish(_ capsule: Capsule) {
        store.didLaunch(capsule)
        draft.reset()
        store.selectedTab = .home
        dismiss()
    }
}

private struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }
}

/// One Ground Control draft: what it says, and Edit / Redo / Remove.
private struct DraftCard: View {
    let item: LayoutItem
    let isRedoing: Bool
    var onEdit: () -> Void
    var onRedo: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.type.displayName.uppercased())
                .font(.orbitHeading(10))
                .tracking(1.2)
                .foregroundStyle(Color.textOnDarkMuted)
            Text(preview)
                .font(.orbitBody(14))
                .foregroundStyle(Color.textOnDark)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: isRedoing ? .placeholder : [])
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                cardButton("Edit", "pencil", action: onEdit)
                if item.type != .recipe {
                    cardButton(isRedoing ? "…" : "Redo", "arrow.clockwise", action: onRedo)
                        .disabled(isRedoing)
                }
                cardButton("Remove", "trash", action: onRemove)
            }
        }
        .padding(14)
        .frame(width: 230, height: 170)
        .orbitCard(fill: .spaceDeep, cornerRadius: 18)
    }

    private var preview: String {
        switch item.type {
        case .song: "\(item.title ?? "") — \(item.artist ?? "")"
        case .recipe: ([item.title ?? "Recipe"] + (item.lines ?? [])).joined(separator: "\n")
        default: item.text ?? ""
        }
    }

    private func cardButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.orbitHeading(11))
                .foregroundStyle(Color.textOnDark)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(SwiftUI.Capsule().fill(Color.panelNavy))
        }
        .buttonStyle(.plain)
    }
}
