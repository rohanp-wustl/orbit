import SwiftUI
import AVFoundation
import CoreTransferable
import Speech
import UniformTypeIdentifiers

/// A voice note recorded in the builder.
struct VoiceNote: Identifiable {
    let mediaId: String
    let fileURL: URL
    let duration: Double
    /// On-device transcript (Speech framework) — context for Ground Control
    /// only; the audio itself never goes to the AI.
    var transcript: String?

    var id: String { mediaId }
}

/// A video picked in the builder: the file, one poster frame (the only
/// thing Ground Control sees), and its length.
struct VideoClip {
    let mediaId: String
    let fileURL: URL
    let poster: UIImage
    let posterBase64: String
    let duration: Double
}

/// Imports a picked video as a local file copy.
struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}

enum VoiceTranscriber {
    /// Transcribes a recorded file on the device (iOS 26+ SpeechAnalyzer).
    /// Returns nil when the language model isn't available — the note still
    /// works, Ground Control just gets less context.
    static func transcribe(_ url: URL) async -> String? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else { return nil }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        if let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try? await request.downloadAndInstall()
        }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let collector = Task {
            var text = ""
            do {
                for try await result in transcriber.results {
                    text += String(result.text.characters)
                }
            } catch {
                return text
            }
            return text
        }
        do {
            _ = try await SpeechAnalyzer(inputAudioFile: file, modules: [transcriber], finishAfterFile: true)
        } catch {
            collector.cancel()
            return nil
        }
        let text = await collector.value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// Record a voice note (max 60s). Big pulsing button, live level meter,
/// then an on-device transcript preview before adding it.
struct VoiceRecorderSheet: View {
    var onAdd: (VoiceNote) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recorder: AVAudioRecorder?
    @State private var fileURL: URL?
    @State private var isRecording = false
    @State private var elapsed: Double = 0
    @State private var level: Double = 0
    @State private var transcript: String?
    @State private var isTranscribing = false
    @State private var permissionDenied = false

    private static let maxSeconds: Double = 60

    var body: some View {
        VStack(spacing: 24) {
            Text("Voice note")
                .font(.orbitDisplay(26))
                .foregroundStyle(Color.textOnDark)
                .padding(.top, 28)
            Text(isRecording ? "Recording…" : (fileURL == nil ? "Tap to record up to a minute." : "Nice. Add it, or record again."))
                .font(.orbitBody(14))
                .foregroundStyle(Color.textOnDarkMuted)

            Text(LaunchView.duration(Int(elapsed)))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.textOnDark)
                .contentTransition(.numericText())

            Button {
                if isRecording { stop() } else { Task { await start() } }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.orbitEmber.opacity(0.25))
                        .scaleEffect(1 + level * 0.6)
                    Circle()
                        .fill(RadialGradient(colors: [Color.orbitEmber.lightened(by: 0.3), .orbitEmber], center: .init(x: 0.35, y: 0.3),
                                             startRadius: 0, endRadius: 50))
                        .frame(width: 88, height: 88)
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 130, height: 130)
                .animation(.easeOut(duration: 0.1), value: level)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

            if isTranscribing {
                ProgressView("Transcribing on your phone…").tint(.white).foregroundStyle(Color.textOnDarkMuted)
            } else if let transcript {
                Text("\u{201C}\(transcript)\u{201D}")
                    .font(.orbitBody(14))
                    .foregroundStyle(Color.textOnDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 24)
                Text("Only Ground Control reads this transcript, to write better captions.")
                    .font(.orbitBody(11))
                    .foregroundStyle(Color.textOnDarkMuted)
            }

            if permissionDenied {
                Text("Microphone access is off. Turn it on in Settings → Orbit.")
                    .font(.orbitBody(13))
                    .foregroundStyle(Color.orbitEmber.lightened(by: 0.3))
            }

            Spacer()

            Button("Add to package") {
                guard let fileURL else { return }
                onAdd(VoiceNote(mediaId: UUID().uuidString.lowercased(), fileURL: fileURL, duration: elapsed, transcript: transcript))
                dismiss()
            }
            .buttonStyle(OrbitPillButtonStyle(color: .orbitGold, textColor: .spaceDeep))
            .disabled(fileURL == nil || isRecording || isTranscribing)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(StarfieldBackground(base: .panelNavy, starCount: 25))
        .presentationDetents([.large])
        .onDisappear { recorder?.stop() }
    }

    private func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            permissionDenied = true
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let newRecorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        newRecorder.isMeteringEnabled = true
        newRecorder.record(forDuration: Self.maxSeconds)
        recorder = newRecorder
        fileURL = nil
        transcript = nil
        elapsed = 0
        isRecording = true
        // Tick the timer + level meter until stopped or the 60s cap hits.
        while isRecording, newRecorder.isRecording {
            try? await Task.sleep(for: .milliseconds(100))
            newRecorder.updateMeters()
            elapsed = newRecorder.currentTime
            level = Double(max(0, (newRecorder.averagePower(forChannel: 0) + 50) / 50))
        }
        if isRecording { stop() }
        _ = url
    }

    private func stop() {
        guard let recorder else { return }
        elapsed = max(elapsed, recorder.currentTime)
        recorder.stop()
        isRecording = false
        level = 0
        fileURL = recorder.url
        let url = recorder.url
        Task {
            isTranscribing = true
            transcript = await VoiceTranscriber.transcribe(url)
            isTranscribing = false
        }
    }
}
