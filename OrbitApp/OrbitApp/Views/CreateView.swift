import SwiftUI
import PhotosUI

/// Ground Control input: what the capsule is for (docs/AI_SPEC.md "Inputs").
enum Occasion: String, CaseIterable, Identifiable {
    case justBecause = "Just because", missYou = "Miss you", birthday = "Birthday", congrats = "Congrats",
         holiday = "Holiday", getWell = "Get well", thankYou = "Thank you"
    var id: String { rawValue }
}

/// Ground Control input: the tone to write in.
enum Mood: String, CaseIterable, Identifiable {
    case sweet = "Sweet", funny = "Funny", nostalgic = "Nostalgic", hype = "Hype", cozy = "Cozy"
    var id: String { rawValue }
}

/// How long the rocket flies. The sender chooses (open question resolved:
/// default Warp for demos; real use picks Cruise/Scenic/Overnight).
enum DeliverySpeed: String, CaseIterable, Identifiable {
    case warp = "Warp", cruise = "Cruise", scenic = "Scenic", overnight = "Overnight"
    var id: String { rawValue }

    var detail: String {
        switch self {
        case .warp: "10 sec"
        case .cruise: "1 min"
        case .scenic: "1 hour"
        case .overnight: "8 am"
        }
    }

    /// Flight time from now. Overnight lands at the next 8:00 AM local time.
    func seconds(from now: Date = .now) -> Int {
        switch self {
        case .warp: return 10
        case .cruise: return 60
        case .scenic: return 3600
        case .overnight:
            let calendar = Calendar.current
            var next = calendar.nextDate(after: now, matching: DateComponents(hour: 8, minute: 0), matchingPolicy: .nextTime) ?? now
            if next.timeIntervalSince(now) < 3600 { next = next.addingTimeInterval(86_400) }
            return Int(next.timeIntervalSince(now))
        }
    }
}

/// A package being assembled. Owned by MainTabView so switching tabs
/// mid-build doesn't lose anything.
@Observable
final class CapsuleDraft {
    var recipientId: UUID?
    var hue: OrbitHue = .magenta
    var occasion: Occasion = .justBecause
    var mood: Mood = .sweet
    var speed: DeliverySpeed = .warp
    var pickerItems: [PhotosPickerItem] = []
    var photos: [PreparedPhoto] = []
    var isLoadingPhotos = false
    var voiceNotes: [VoiceNote] = []
    var videoItem: PhotosPickerItem?
    var video: VideoClip?
    var isLoadingVideo = false
    var notes = ""
    /// true = skip Ground Control and open the editor with a plain template.
    var buildItMyself = false
    /// Shown on the Create screen when the launch flow bails out (e.g. upload failed).
    var errorMessage: String?

    static let maxPhotos = 4
    static let maxVideoSeconds: Double = 60

    var hasContent: Bool {
        !photos.isEmpty || !voiceNotes.isEmpty || video != nil
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadVideo() async {
        guard let videoItem else { video = nil; return }
        isLoadingVideo = true
        defer { isLoadingVideo = false }
        guard let movie = try? await videoItem.loadTransferable(type: Movie.self) else {
            errorMessage = "Couldn't load that video."
            return
        }
        let duration = await VideoFrames.duration(of: movie.url)
        guard duration <= Self.maxVideoSeconds else {
            errorMessage = "Keep videos under a minute (that one's \(Int(duration))s)."
            self.videoItem = nil
            return
        }
        guard let poster = await VideoFrames.poster(for: movie.url),
              let prepared = await MediaRepository.prepare(poster.jpegData(compressionQuality: 0.8) ?? Data()) else { return }
        let mediaId = UUID().uuidString.lowercased()
        MediaRepository.shared.remember(image: prepared.image, for: mediaId)
        MediaRepository.shared.remember(file: movie.url, for: mediaId)
        video = VideoClip(mediaId: mediaId, fileURL: movie.url, poster: prepared.image,
                          posterBase64: prepared.thumbnailBase64, duration: duration)
        errorMessage = nil
    }

    func loadPhotos() async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        var loaded: [PreparedPhoto] = []
        for item in pickerItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let photo = await MediaRepository.prepare(data) {
                loaded.append(photo)
            }
        }
        photos = loaded
    }

    func reset() {
        recipientId = nil
        hue = .magenta
        occasion = .justBecause
        mood = .sweet
        speed = .warp
        pickerItems = []
        photos = []
        voiceNotes = []
        videoItem = nil
        video = nil
        notes = ""
        buildItMyself = false
        errorMessage = nil
    }
}

/// The Create tab (style sheet §5 "Create"): recipient, package color,
/// what goes inside, then Launch → Ground Control → editor → liftoff.
struct CreateView: View {
    @Environment(OrbitStore.self) private var store
    @Bindable var draft: CapsuleDraft

    @State private var showNoteEditor = false
    @State private var showRecipientPicker = false
    @State private var showVoiceRecorder = false
    @State private var showLaunchFlow = false
    @State private var comingSoon: String?
    @State private var bounce = 0

    private var recipient: AppUser? {
        store.crewMembers.first { $0.id == draft.recipientId }
    }
    private var canLaunch: Bool { recipient != nil && draft.hasContent && !draft.isLoadingPhotos }

    var body: some View {
        ZStack {
            StarfieldBackground(base: .panelNavy, starCount: 30)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("New package")
                        .font(.orbitDisplay(30))
                        .foregroundStyle(Color.textOnDark)
                        .frame(maxWidth: .infinity)

                    packagePreview
                    recipientRow

                    section("Package color") { swatches }
                    section("Occasion") { ChipRow(options: Occasion.allCases, selection: $draft.occasion) { $0.rawValue } }
                    section("Mood") { ChipRow(options: Mood.allCases, selection: $draft.mood) { $0.rawValue } }
                    section("Add to package") { tiles }
                    section("Delivery speed") {
                        ChipRow(options: DeliverySpeed.allCases, selection: $draft.speed) { "\($0.rawValue) · \($0.detail)" }
                    }

                    if let errorMessage = draft.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.orbitBody(13))
                            .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
                    }

                    Button {
                        draft.errorMessage = nil
                        draft.buildItMyself = false
                        showLaunchFlow = true
                    } label: {
                        Label("Pack & launch", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(OrbitPillButtonStyle())
                    .disabled(!canLaunch)
                    .opacity(canLaunch ? 1 : 0.5)

                    // Hand-made capsules are the same data as Ground Control's —
                    // this just skips the AI and opens the editor on a plain template.
                    Button {
                        draft.errorMessage = nil
                        draft.buildItMyself = true
                        showLaunchFlow = true
                    } label: {
                        Text("or build it myself")
                            .font(.orbitHeading(15))
                            .foregroundStyle(Color.skyGlass)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canLaunch)
                    .opacity(canLaunch ? 1 : 0.4)

                    if !canLaunch {
                        Text(launchHint)
                            .font(.orbitBody(13))
                            .foregroundStyle(Color.textOnDarkMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)

            if let comingSoon {
                Text(comingSoon)
                    .font(.orbitHeading(14))
                    .foregroundStyle(Color.textOnLight)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(SwiftUI.Capsule().fill(Color.cardWhite).shadow(radius: 10))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear(perform: applyPreselection)
        .onChange(of: store.preselectedRecipient) { _, _ in applyPreselection() }
        .onChange(of: draft.pickerItems) { _, _ in
            Task { await draft.loadPhotos() }
        }
        .onChange(of: draft.videoItem) { _, _ in
            Task { await draft.loadVideo() }
        }
        .sheet(isPresented: $showNoteEditor) {
            NoteEditorSheet(notes: $draft.notes)
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderSheet { note in draft.voiceNotes.append(note) }
        }
        .fullScreenCover(isPresented: $showLaunchFlow) {
            LaunchFlowView(draft: draft)
                .environment(store)
        }
    }

    private var launchHint: String {
        if store.crewMembers.isEmpty { return "Add someone to your crew in Galaxy first" }
        if recipient == nil { return "Pick who this package is for" }
        return "Add a photo, video, voice note, or note to pack inside"
    }

    // MARK: - Pieces

    /// The package and the rocket that will carry it, both in the chosen hue.
    private var packagePreview: some View {
        HStack(alignment: .bottom, spacing: 18) {
            GiftBoxView(hue: draft.hue.color, size: 92)
            RocketView(height: 150, hue: draft.hue.color, cargo: draft.hue.color)
                .padding(.bottom, -150 * RocketView.flameSpace + 6)
        }
            .keyframeAnimator(initialValue: 1.0, trigger: bounce) { view, scale in
                view.scaleEffect(scale, anchor: .bottom)
            } keyframes: { _ in
                SpringKeyframe(1.18, duration: 0.15)
                SpringKeyframe(0.94, duration: 0.15)
                SpringKeyframe(1.0, duration: 0.3)
            }
            .phaseAnimator([0.0, -3, 3, 0]) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: .bottom)
            } animation: { _ in .easeInOut(duration: 0.9) }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(draft.hue.rawValue.capitalized) package and rocket")
    }

    private var recipientRow: some View {
        Button {
            if store.crewMembers.isEmpty {
                store.selectedTab = .galaxy
            } else {
                showRecipientPicker = true
            }
        } label: {
            recipientLabel(name: recipient?.displayName, empty: store.crewMembers.isEmpty)
                .padding(16)
                .orbitCard(fill: .spaceDeep, cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showRecipientPicker) {
            RecipientPickerSheet(members: store.crewMembers, selection: $draft.recipientId)
        }
    }

    private func recipientLabel(name: String?, empty: Bool) -> some View {
        HStack(spacing: 12) {
            if let recipient {
                ShadedPlanet(hue: OrbitHue.forUser(recipient.id).color, size: 30, surface: .smooth, spinSpeed: 0, glow: false)
            } else {
                Image(systemName: empty ? "person.badge.plus" : "person.crop.circle.badge.questionmark")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.skyGlass)
                    .frame(width: 30)
            }
            Text(name.map { "To: \($0)" } ?? (empty ? "Add crew in Galaxy" : "Choose a crew member"))
                .font(.orbitHeading(16))
                .foregroundStyle(Color.textOnDark)
            Spacer()
            Image(systemName: empty ? "arrow.right" : "chevron.right")
                .foregroundStyle(Color.textOnDarkMuted)
        }
        .contentShape(Rectangle())
    }

    private var swatches: some View {
        HStack(spacing: 12) {
            ForEach(OrbitHue.allCases) { hue in
                Button {
                    draft.hue = hue
                    bounce += 1
                } label: {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [hue.color.lightened(by: 0.25), hue.color, hue.color.darkened(by: 0.2)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white, lineWidth: draft.hue == hue ? 3 : 0)
                        }
                        .frame(width: 42, height: 42)
                        .scaleEffect(draft.hue == hue ? 1.12 : 1)
                        .shadow(color: hue.color.opacity(draft.hue == hue ? 0.7 : 0), radius: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hue.rawValue.capitalized)
                .accessibilityAddTraits(draft.hue == hue ? .isSelected : [])
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.5), value: draft.hue)
        .sensoryFeedback(.selection, trigger: draft.hue)
    }

    private var tiles: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                PhotosPicker(selection: $draft.pickerItems, maxSelectionCount: CapsuleDraft.maxPhotos, matching: .images) {
                    AttachTile(title: "Photo", icon: .photo,
                               detail: draft.isLoadingPhotos ? "Loading…" : (draft.photos.isEmpty ? "Up to 4" : "\(draft.photos.count) added"),
                               filled: !draft.photos.isEmpty)
                }
                .buttonStyle(.plain)

                Button {
                    if draft.voiceNotes.count < LayoutItemType.audio.limit {
                        showVoiceRecorder = true
                    } else {
                        showSoon("Two voice notes max per capsule")
                    }
                } label: {
                    AttachTile(title: "Voice", icon: .voice,
                               detail: draft.voiceNotes.isEmpty ? "Record up to 1 min" : "\(draft.voiceNotes.count) recorded",
                               filled: !draft.voiceNotes.isEmpty)
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $draft.videoItem, matching: .videos) {
                    AttachTile(title: "Video", icon: .video,
                               detail: draft.isLoadingVideo ? "Loading…" : (draft.video == nil ? "Up to 1 min" : "\(Int(draft.video?.duration ?? 0))s clip"),
                               filled: draft.video != nil)
                }
                .buttonStyle(.plain)

                Button { showNoteEditor = true } label: {
                    AttachTile(title: "Note", icon: .note,
                               detail: draft.notes.isEmpty ? "For Ground Control" : "Written",
                               filled: !draft.notes.isEmpty)
                }
                .buttonStyle(.plain)
            }

            if !draft.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(Array(draft.photos.enumerated()), id: \.element.mediaId) { index, photo in
                            Image(uiImage: photo.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -4 : 4))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(6)
                }
                .scrollIndicators(.hidden)
            }

            ForEach(draft.voiceNotes) { note in
                attachmentRow(icon: "waveform", color: .orbitGold,
                              title: "Voice note · \(LaunchView.duration(Int(note.duration)))",
                              subtitle: note.transcript.map { "\u{201C}\($0)\u{201D}" } ?? "No transcript") {
                    draft.voiceNotes.removeAll { $0.id == note.id }
                }
            }
            if let video = draft.video {
                attachmentRow(image: video.poster, title: "Video · \(Int(video.duration))s",
                              subtitle: "Ground Control sees one frame, not the video") {
                    draft.video = nil
                    draft.videoItem = nil
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: draft.photos.count)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: draft.voiceNotes.count)
    }

    private func attachmentRow(icon: String = "", color: Color = .skyGlass, image: UIImage? = nil,
                               title: String, subtitle: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.spaceDeep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.orbitHeading(14)).foregroundStyle(Color.textOnDark)
                Text(subtitle).font(.orbitBody(11)).foregroundStyle(Color.textOnDarkMuted).lineLimit(1)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(Color.textOnDarkMuted)
            }
            .accessibilityLabel("Remove \(title)")
        }
        .padding(10)
        .orbitCard(fill: .spaceDeep, cornerRadius: 16)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.orbitHeading(14))
                .foregroundStyle(Color.textOnDarkMuted)
            content()
        }
    }

    private func showSoon(_ message: String) {
        withAnimation(.spring) { comingSoon = message }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut) { comingSoon = nil }
        }
    }

    private func applyPreselection() {
        if let preselected = store.preselectedRecipient {
            draft.recipientId = preselected
            store.preselectedRecipient = nil
        } else if draft.recipientId == nil, store.crewMembers.count == 1 {
            draft.recipientId = store.crewMembers.first?.id
        }
    }
}

/// One of the four "Add to package" tiles, with a small shaded 3D icon.
private struct AttachTile: View {
    enum Icon { case photo, voice, video, note }

    let title: String
    let icon: Icon
    let detail: String
    let filled: Bool
    var locked = false

    var body: some View {
        VStack(spacing: 10) {
            iconView
                .frame(width: 34, height: 34)
                .overlay(alignment: .topTrailing) {
                    if filled {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.orbitSeafoam, Color.spaceDeep)
                            .offset(x: 10, y: -8)
                            .transition(.scale)
                    }
                }
            VStack(spacing: 2) {
                Text(title)
                    .font(.orbitHeading(15))
                    .foregroundStyle(Color.textOnDark)
                Text(detail)
                    .font(.orbitBody(11))
                    .foregroundStyle(Color.textOnDarkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .orbitCard(fill: .spaceDeep, cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orbitSeafoam.opacity(filled ? 0.8 : 0), lineWidth: 2)
        }
        .opacity(locked ? 0.6 : 1)
        .animation(.spring(duration: 0.3), value: filled)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .photo:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [Color.skyGlass.lightened(by: 0.3), .skyGlass, Color.skyGlass.darkened(by: 0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .bottom) {
                    // Little mountain range = "photo".
                    Triangle().fill(Color.accentBlue.opacity(0.7)).frame(width: 22, height: 12).offset(x: -3)
                }
                .overlay(alignment: .topTrailing) {
                    Circle().fill(Color.orbitGold).frame(width: 7, height: 7).padding(5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .skyGlass.opacity(0.5), radius: 6)
        case .voice:
            Circle()
                .fill(RadialGradient(colors: [Color.orbitGold.lightened(by: 0.35), .orbitGold, Color.orbitGold.darkened(by: 0.25)],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 22))
                .overlay(Image(systemName: "waveform").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.spaceDeep.opacity(0.6)))
                .shadow(color: .orbitGold.opacity(0.5), radius: 6)
        case .video:
            Triangle()
                .fill(LinearGradient(colors: [Color.orbitMagenta.lightened(by: 0.3), .orbitMagenta, Color.orbitMagenta.darkened(by: 0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .rotationEffect(.degrees(90))
                .shadow(color: .orbitMagenta.opacity(0.5), radius: 6)
        case .note:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [Color.orbitSeafoam.lightened(by: 0.3), .orbitSeafoam, Color.orbitSeafoam.darkened(by: 0.2)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            SwiftUI.Capsule().fill(Color.spaceDeep.opacity(0.35)).frame(width: 18, height: 3)
                        }
                    }
                }
                .shadow(color: .orbitSeafoam.opacity(0.5), radius: 6)
        }
    }
}

/// Horizontally scrolling single-choice chips (occasion, mood, speed).
struct ChipRow<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    var label: (Option) -> String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    let selected = option == selection
                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.orbitHeading(13))
                            .foregroundStyle(selected ? Color.spaceDeep : Color.textOnDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(SwiftUI.Capsule().fill(selected ? Color.skyGlass : Color.spaceDeep))
                            .overlay(SwiftUI.Capsule().strokeBorder(.white.opacity(selected ? 0 : 0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Pick who the package is for — your crew, as their planets.
private struct RecipientPickerSheet: View {
    let members: [AppUser]
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send to…")
                .font(.orbitDisplay(24))
                .foregroundStyle(Color.textOnDark)
                .padding(.top, 24)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(members) { member in
                        Button {
                            selection = member.id
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                ShadedPlanet(hue: OrbitHue.forUser(member.id).color, size: 40, spinSpeed: 0.3)
                                Text(member.displayName)
                                    .font(.orbitHeading(17))
                                    .foregroundStyle(Color.textOnDark)
                                Spacer()
                                if selection == member.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.orbitSeafoam)
                                }
                            }
                            .padding(14)
                            .orbitCard(fill: .spaceDeep, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(StarfieldBackground(base: .panelNavy, starCount: 25))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Write the note that Ground Control turns into captions.
private struct NoteEditorSheet: View {
    @Binding var notes: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Inside jokes, what you did today, what you miss. Ground Control writes captions from this in your voice.")
                    .font(.orbitBody(14))
                    .foregroundStyle(Color.textOnDarkMuted)
                TextEditor(text: $notes)
                    .font(.orbitBody(17))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .orbitCard(fill: .spaceDeep, cornerRadius: 18)
            }
            .padding(20)
            .background(Color.panelNavy.ignoresSafeArea())
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        CreateView(draft: CapsuleDraft())
        OrbitTabBar(selection: .constant(.create), light: false, homeBadge: 1)
    }
    .environment(OrbitStore.preview)
}
