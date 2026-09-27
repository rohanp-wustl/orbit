import SwiftUI

/// Pages are always 3:4 so a layout's fractional x/y/w land in the same
/// place on every screen size.
let capsulePageAspectRatio: CGFloat = 3.0 / 4.0

/// Read-only render of a whole capsule page. Used by CapsuleDetailView and
/// UnboxingView; CapsuleEditorView composes the same pieces
/// (CapsuleBackground + LayoutItemView) with gestures on top.
struct CapsulePageView: View {
    let layout: CapsuleLayout
    /// Whose Storage folder the photos live in — always the capsule's sender.
    let senderId: UUID
    /// Only these items are drawn (for the unboxing reveal); nil = all.
    var visibleItemIds: Set<String>? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CapsuleBackground(name: layout.background)
                ForEach(layout.items.sorted { $0.z < $1.z }) { item in
                    if visibleItemIds?.contains(item.id) ?? true {
                        LayoutItemView(item: item, pageWidth: geo.size.width,
                                       senderId: senderId, inkColor: CapsuleBackground.inkColor(for: layout.background))
                            .rotationEffect(.degrees(item.rotation))
                            .position(x: item.x * geo.size.width, y: item.y * geo.size.height)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
        }
        .aspectRatio(capsulePageAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}

// MARK: - Background

/// Draws each background name from OrbitAssets.backgrounds. Swap a case
/// for `Image(name).resizable()` once Design ships the real art.
struct CapsuleBackground: View {
    let name: String

    /// Text color that reads well on this background.
    static func inkColor(for name: String) -> Color {
        name == "night_sky" ? .textOnDark : .inkBrown
    }

    var body: some View {
        switch name {
        case "night_sky":
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.spaceDeep))
                // Fixed pseudo-random star field so it doesn't reshuffle on redraw.
                var seed: UInt64 = 42
                for _ in 0..<60 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 40 & 0xFFFF) / 65535 * size.width
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed >> 40 & 0xFFFF) / 65535 * size.height
                    let r = CGFloat(seed >> 20 & 0x3) * 0.6 + 0.8
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(.white.opacity(0.8)))
                }
            }
        case "sunset_wash":
            LinearGradient(colors: [.orbitMagenta.lightened(by: 0.65), .orbitGold.lightened(by: 0.55)],
                           startPoint: .top, endPoint: .bottom)
        case "mint_grid":
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.orbitSeafoam.lightened(by: 0.82)))
                let step = size.width / 16
                var grid = Path()
                for x in stride(from: step, to: size.width, by: step) {
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: step, to: size.height, by: step) {
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.orbitSeafoam.opacity(0.35)), lineWidth: 0.5)
            }
        default: // "kraft_paper_02" and anything unrecognized
            Color.kraftPaper
        }
    }
}

// MARK: - Items

/// One placed item, sized from its fractional width. Position and rotation
/// are applied by the caller.
struct LayoutItemView: View {
    let item: LayoutItem
    let pageWidth: CGFloat
    let senderId: UUID
    var inkColor: Color = .inkBrown

    private var width: CGFloat { item.w * pageWidth }

    var body: some View {
        switch item.type {
        case .photo:
            FramedPhoto(mediaId: item.media, senderId: senderId, frame: item.frame, width: width)
        case .video:
            VideoClipView(mediaId: item.media, senderId: senderId, width: width)
        case .audio:
            CassetteView(mediaId: item.media, senderId: senderId, label: item.text, width: width)
        case .text:
            Text(item.text ?? "")
                .font(Self.font(named: item.font, size: pageWidth * 0.062))
                .foregroundStyle(inkColor)
                .multilineTextAlignment(.center)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)
        case .letter:
            letterCard
        case .question:
            questionCard
        case .song:
            songCard
        case .recipe:
            recipeCard
        case .sticker:
            if item.asset == "beach" {
                // Design's hand-drawn sticker art.
                Image("sticker_beach").resizable().scaledToFit().frame(width: width)
            } else {
                Text(Self.stickerEmoji[item.asset ?? ""] ?? "⭐️")
                    .font(.system(size: width * 0.8))
            }
        }
    }

    // MARK: - Word items

    /// A short handwritten note on lined paper.
    private var letterCard: some View {
        Text(item.text ?? "")
            .font(Self.font(named: item.font ?? "handwritten", size: pageWidth * 0.034))
            .foregroundStyle(Color.inkBrown)
            .lineSpacing(pageWidth * 0.006)
            .multilineTextAlignment(.leading)
            // Long letters shrink to fit rather than run off the page.
            .lineLimit(9)
            .minimumScaleFactor(0.6)
            .padding(pageWidth * 0.04)
            .frame(width: width, alignment: .leading)
            .background(
                ZStack(alignment: .top) {
                    Color(hex: "#FFFDF6")
                    VStack(spacing: pageWidth * 0.045) {
                        ForEach(0..<14, id: \.self) { _ in
                            Rectangle().fill(Color.skyGlass.opacity(0.35)).frame(height: 0.7)
                        }
                    }
                    .padding(.top, pageWidth * 0.1)
                }
            )
            // Clip the card itself: the ruled-line pattern is taller than short letters.
            .clipped()
            .overlay(alignment: .top) { tape(width: width * 0.3).offset(y: -pageWidth * 0.015) }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    /// A question for the recipient — the nudge to send one back.
    private var questionCard: some View {
        VStack(spacing: pageWidth * 0.015) {
            Text("A QUESTION FOR YOU")
                .font(.system(size: pageWidth * 0.026, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Color.orbitViolet)
            Text(item.text ?? "")
                .font(Self.font(named: item.font ?? "marker", size: pageWidth * 0.05))
                .foregroundStyle(Color.textOnLight)
                .multilineTextAlignment(.center)
        }
        .padding(pageWidth * 0.035)
        .frame(width: width)
        .background(SpeechBubble().fill(Color(hex: "#F3EEFF")))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    /// A song suggestion. Links out to Apple Music; we never upload the song.
    @ViewBuilder
    private var songCard: some View {
        let content = HStack(spacing: pageWidth * 0.02) {
            ZStack {
                Circle().fill(Color.hullCap)
                Circle().fill(Color.orbitMagenta).frame(width: pageWidth * 0.03, height: pageWidth * 0.03)
            }
            .frame(width: pageWidth * 0.08, height: pageWidth * 0.08)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title ?? "")
                    .font(.system(size: pageWidth * 0.036, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textOnLight)
                    .lineLimit(1)
                Text(item.artist ?? "")
                    .font(.system(size: pageWidth * 0.03, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.textOnLightMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill")
                .font(.system(size: pageWidth * 0.05))
                .foregroundStyle(Color.orbitMagenta)
        }
        .padding(pageWidth * 0.025)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: pageWidth * 0.03).fill(Color.cardWhite))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

        if let url = item.songURL {
            Link(destination: url) { content }
                .accessibilityLabel("Song: \(item.title ?? ""), \(item.artist ?? ""). Opens Apple Music.")
        } else {
            content
        }
    }

    /// An index card with the recipe the sender typed.
    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: pageWidth * 0.012) {
            Text(item.title ?? "Recipe")
                .font(Self.font(named: "marker", size: pageWidth * 0.042))
                .foregroundStyle(Color.orbitEmber)
            Rectangle().fill(Color.orbitEmber.opacity(0.5)).frame(height: 1)
            ForEach(Array((item.lines ?? []).prefix(8).enumerated()), id: \.offset) { _, line in
                Text("• \(line)")
                    .font(Self.font(named: "handwritten", size: pageWidth * 0.026))
                    .foregroundStyle(Color.inkBrown)
            }
        }
        .padding(pageWidth * 0.035)
        .frame(width: width, alignment: .leading)
        .background(Color(hex: "#FFF8EC"))
        .overlay(alignment: .topTrailing) { tape(width: width * 0.25).rotationEffect(.degrees(20)).offset(x: 8, y: -4) }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private func tape(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.skyGlass.opacity(0.55))
            .frame(width: width, height: width * 0.28)
            .rotationEffect(.degrees(-3))
    }

    /// Emoji stand-ins for OrbitAssets.stickers until real sticker art exists.
    static let stickerEmoji: [String: String] = [
        "star": "⭐️", "heart": "💖", "rocket": "🚀", "planet": "🪐", "sparkle": "✨",
        "sun": "☀️", "moon": "🌙", "music_note": "🎶", "coffee": "☕️", "paw": "🐾",
    ]

    /// Maps OrbitAssets.fonts names to real fonts. "handwritten" uses the
    /// theme's Caveat, which falls back to the system font until the font
    /// file is added (see Resources/README_ASSETS.md).
    static func font(named name: String?, size: CGFloat) -> Font {
        switch name {
        case "marker": .system(size: size, weight: .heavy, design: .rounded)
        case "typewriter": .system(size: size * 0.85, design: .monospaced)
        default: .orbitHandwritten(size * 1.2)
        }
    }
}

/// A photo loaded from MediaRepository, wrapped in its frame style.
private struct FramedPhoto: View {
    let mediaId: String?
    let senderId: UUID
    let frame: String?
    let width: CGFloat

    @State private var image: UIImage?
    @State private var didFail = false

    init(mediaId: String?, senderId: UUID, frame: String?, width: CGFloat) {
        self.mediaId = mediaId
        self.senderId = senderId
        self.frame = frame
        self.width = width
        // Draw cached photos on the first frame (the launch snapshot can't wait for .task).
        _image = State(initialValue: MediaRepository.shared.cachedImage(mediaId))
    }

    var body: some View {
        framed
            .task(id: mediaId) {
                guard let mediaId else { return }
                image = await MediaRepository.shared.image(mediaId: mediaId, senderId: senderId)
                didFail = image == nil
            }
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.cloudGray.opacity(0.5))
                .overlay {
                    if didFail {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }
        }
    }

    @ViewBuilder
    private var framed: some View {
        switch frame {
        case "polaroid":
            let inset = width * 0.05
            photo
                .frame(width: width - inset * 2, height: width - inset * 2)
                .clipped()
                .padding([.top, .horizontal], inset)
                .padding(.bottom, inset * 3.5)
                .background(Color.cardWhite)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        case "tape":
            photo
                .frame(width: width, height: width * 0.8)
                .clipped()
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.skyGlass.opacity(0.55))
                        .frame(width: width * 0.4, height: width * 0.1)
                        .rotationEffect(.degrees(-4))
                        .offset(y: -width * 0.04)
                }
        default:
            photo
                .frame(width: width, height: width * 0.8)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.04))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
}

#Preview {
    CapsulePageView(
        layout: CapsuleLayout(background: "night_sky", template: "scrapbook_collage", items: [
            // media: nil so the preview shows the placeholder without a
            // network call (async Storage loads crash the Previews JIT).
            LayoutItem(id: "p1", type: .photo, media: nil, x: 0.35, y: 0.3, w: 0.5, rotation: -6, z: 1, frame: "polaroid"),
            LayoutItem(id: "t1", type: .text, text: "the banana bread was a crime", font: "handwritten", x: 0.5, y: 0.72, w: 0.8, z: 2),
            LayoutItem(id: "s1", type: .sticker, asset: "rocket", x: 0.78, y: 0.18, w: 0.18, rotation: 12, z: 3),
        ]),
        senderId: UUID()
    )
    .padding()
}
