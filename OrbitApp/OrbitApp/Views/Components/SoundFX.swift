import AVFoundation

/// Tiny synthesized sound effects for the launch and unboxing moments —
/// generated in code (no audio files to license or bundle). Uses the
/// `.ambient` session category, so it respects the silent switch and mixes
/// with the user's music. Toggle: Settings → Sound & haptics.
enum SoundFX {
    enum Effect: CaseIterable {
        case beep, clunk, liftoff, pop, chime, tick, landing
    }

    static func play(_ effect: Effect) {
        guard UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true else { return }
        Engine.shared.play(effect)
    }

    private final class Engine {
        static let shared = Engine()

        private let engine = AVAudioEngine()
        private let players: [AVAudioPlayerNode]
        private var nextPlayer = 0
        private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        private var buffers: [Effect: AVAudioPCMBuffer] = [:]
        private var started = false

        private init() {
            // A few voices so overlapping effects (beep over rumble) don't cut each other off.
            players = (0..<4).map { _ in AVAudioPlayerNode() }
            for player in players {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
            }
            engine.mainMixerNode.outputVolume = 0.6
        }

        func play(_ effect: Effect) {
            if !started {
                try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                try? AVAudioSession.sharedInstance().setActive(true)
                do { try engine.start() } catch { return }
                started = true
            }
            let buffer = buffers[effect] ?? makeBuffer(effect)
            buffers[effect] = buffer
            let player = players[nextPlayer]
            nextPlayer = (nextPlayer + 1) % players.count
            player.stop()
            player.scheduleBuffer(buffer, at: nil)
            player.play()
        }

        private func makeBuffer(_ effect: Effect) -> AVAudioPCMBuffer {
            let rate = format.sampleRate
            let duration: Double = switch effect {
            case .beep: 0.14
            case .clunk: 0.25
            case .liftoff: 2.2
            case .pop: 0.35
            case .chime: 0.9
            case .tick: 0.03
            case .landing: 0.8
            }
            let frames = AVAudioFrameCount(duration * rate)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
            buffer.frameLength = frames
            let samples = buffer.floatChannelData![0]
            var rng = SeededRandom(seed: 7)
            var filtered: Float = 0

            for index in 0..<Int(frames) {
                let t = Double(index) / rate
                let progress = t / duration
                var value: Double
                switch effect {
                case .beep:
                    value = sin(2 * .pi * 880 * t) * envelope(progress, attack: 0.05, release: 0.5)
                case .tick:
                    value = sin(2 * .pi * 2200 * t) * (1 - progress)
                case .clunk:
                    let noise = rng.next() * 2 - 1
                    value = (sin(2 * .pi * 95 * t) * 0.8 + noise * 0.3 * exp(-t * 40)) * exp(-t * 14)
                case .liftoff:
                    // Low-passed noise that swells, then fades as the ship leaves.
                    let noise = Float(rng.next() * 2 - 1)
                    filtered += 0.04 * (noise - filtered)
                    let swell = min(1, progress * 3) * pow(1 - progress, 0.6)
                    value = Double(filtered) * 5 * swell + sin(2 * .pi * 48 * t) * 0.25 * swell
                case .pop:
                    let sweep = 700 - 500 * progress
                    let noise = rng.next() * 2 - 1
                    value = sin(2 * .pi * sweep * t) * exp(-t * 12) * 0.7 + noise * exp(-t * 60) * 0.5
                case .chime:
                    value = (sin(2 * .pi * 1046.5 * t) + 0.6 * sin(2 * .pi * 1568 * t) + 0.3 * sin(2 * .pi * 2093 * t))
                        * 0.4 * exp(-t * 4.5) * envelope(progress, attack: 0.01, release: 0.2)
                case .landing:
                    let noise = Float(rng.next() * 2 - 1)
                    filtered += 0.08 * (noise - filtered)
                    value = Double(filtered) * 3 * (1 - progress) + sin(2 * .pi * 70 * t) * 0.5 * exp(-t * 5)
                }
                samples[index] = Float(max(-1, min(1, value)))
            }
            return buffer
        }

        /// Linear attack, linear release over the given fractions of the sound.
        private func envelope(_ progress: Double, attack: Double, release: Double) -> Double {
            if progress < attack { return progress / attack }
            if progress > 1 - release { return max(0, (1 - progress) / release) }
            return 1
        }
    }
}
