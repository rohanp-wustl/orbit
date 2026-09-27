import SwiftUI
import AVFoundation
import AVKit

/// A voice note on the page, drawn as a cassette (per the roadmap's
/// "playable cassette sticker"). Tap to play/pause; the reels spin while
/// it plays.
struct CassetteView: View {
    let mediaId: String?
    let senderId: UUID
    var label: String?
    let width: CGFloat

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var isLoading = false

    var body: some View {
        let height = width * 0.62
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.08)
                .fill(LinearGradient(colors: [Color.orbitGold.lightened(by: 0.2), .orbitGold, Color.orbitGold.darkened(by: 0.15)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: height * 0.06) {
                // Label strip.
                Text(label ?? "Voice note")
                    .font(.system(size: width * 0.075, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.inkBrown)
                    .lineLimit(1)
                    .padding(.horizontal, width * 0.06)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, height * 0.04)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#FFFDF6")))
                    .padding(.horizontal, width * 0.08)
                // Tape window with two reels.
                HStack(spacing: width * 0.18) {
                    reel(size: height * 0.3)
                    reel(size: height * 0.3)
                }
                .padding(.horizontal, width * 0.08)
                .padding(.vertical, height * 0.05)
                .background(SwiftUI.Capsule().fill(Color.hullCap))
            }
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: width * 0.2))
                    .foregroundStyle(.white, Color.orbitMagenta)
                    .shadow(radius: 3)
                    .offset(x: width * 0.36, y: height * 0.32)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { Task { await toggle() } }
        .onDisappear { player?.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Voice note\(label.map { ": \($0)" } ?? ""). \(isPlaying ? "Playing" : "Tap to play").")
        .accessibilityAddTraits(.isButton)
    }

    private func reel(size: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying)) { timeline in
            let angle = isPlaying ? timeline.date.timeIntervalSinceReferenceDate * 240 : 0
            ZStack {
                Circle().fill(Color.cardWhite)
                ForEach(0..<3, id: \.self) { spoke in
                    Rectangle().fill(Color.hullCap).frame(width: size * 0.12, height: size * 0.8)
                        .rotationEffect(.degrees(Double(spoke) * 60))
                }
                Circle().fill(Color.cardWhite).frame(width: size * 0.35)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
        }
    }

    private func toggle() async {
        if let player, isPlaying {
            player.pause()
            isPlaying = false
            return
        }
        if player == nil {
            guard let mediaId else { return }
            isLoading = true
            let url = await MediaRepository.shared.localFile(mediaId: mediaId, senderId: senderId, type: .audio)
            isLoading = false
            // Load from data so the format is sniffed from the bytes: voice notes
            // replied from iMessage are .caf audio stored under a .m4a path.
            guard let url, let data = try? Data(contentsOf: url), let loaded = try? AVAudioPlayer(data: data) else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            player = loaded
        }
        player?.play()
        isPlaying = true
        // Flip back when it finishes.
        if let duration = player?.duration, let current = player?.currentTime {
            try? await Task.sleep(for: .seconds(duration - current + 0.1))
            if player?.isPlaying == false { isPlaying = false }
        }
    }
}

/// A video on the page: poster frame with a play button; tap to play inline.
struct VideoClipView: View {
    let mediaId: String?
    let senderId: UUID
    let width: CGFloat

    @State private var player: AVPlayer?
    @State private var poster: UIImage?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                Group {
                    if let poster {
                        Image(uiImage: poster).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.hullCap)
                    }
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: width * 0.22))
                    .foregroundStyle(.white, Color.black.opacity(0.35))
            }
        }
        .frame(width: width, height: width * 0.75)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.05))
        .padding(width * 0.03)
        .background(Color.cardWhite)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { Task { await play() } }
        .task(id: mediaId) { await loadPoster() }
        .onDisappear { player?.pause() }
        .accessibilityLabel("Video. Tap to play.")
        .accessibilityAddTraits(.isButton)
    }

    private func loadPoster() async {
        guard let mediaId else { return }
        if let cached = await MediaRepository.shared.image(mediaId: mediaId, senderId: senderId) {
            poster = cached
            return
        }
        guard let url = await MediaRepository.shared.localFile(mediaId: mediaId, senderId: senderId, type: .video) else { return }
        poster = await VideoFrames.poster(for: url)
    }

    private func play() async {
        guard player == nil, let mediaId,
              let url = await MediaRepository.shared.localFile(mediaId: mediaId, senderId: senderId, type: .video) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        newPlayer.play()
    }
}

enum VideoFrames {
    /// One still frame (Ground Control only ever sees this, never the video)
    /// plus the clip length, per docs/AI_SPEC.md.
    static func poster(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)
        guard let (cgImage, _) = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func duration(of url: URL) async -> Double {
        let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        return seconds.isFinite ? seconds : 0
    }
}
