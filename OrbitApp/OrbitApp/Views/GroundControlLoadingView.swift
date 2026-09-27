import SwiftUI

/// Shown while photos upload and Ground Control lays out the page
/// (~10s — see docs/AI_CONTRACT.md). Cosmo floats inside a ring of
/// orbiting sparks while mission-control status lines cycle, so the wait
/// feels like part of the ritual rather than a spinner.
struct GroundControlLoadingView: View {
    var recipientName: String = "your crew"
    /// Shown after 12s so a slow model never traps the sender.
    var onSkip: (() -> Void)? = nil

    @State private var lineIndex = 0
    @State private var spin = false
    @State private var showSkip = false

    private var lines: [String] {
        [
            "Scanning your photos…",
            "Picking the perfect background…",
            "Writing captions in your voice…",
            "Sprinkling in stickers…",
            "Tightening the bow for \(recipientName)…",
        ]
    }

    var body: some View {
        ZStack {
            StarfieldBackground(speed: 1.6)

            VStack(spacing: 28) {
                Text("Ground Control")
                    .font(.orbitHeading(14))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundStyle(Color.skyGlass)

                ZStack {
                    // Dashed orbit tracks.
                    ForEach([150.0, 210.0], id: \.self) { diameter in
                        Circle()
                            .stroke(Color.textOnDarkMuted.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 7]))
                            .frame(width: diameter, height: diameter)
                    }
                    // Sparks riding the tracks at different speeds.
                    ForEach(Array(zip([75.0, 105.0, 105.0], [OrbitHue.gold, .magenta, .seafoam]).enumerated()), id: \.offset) { index, pair in
                        Circle()
                            .fill(pair.1.color)
                            .frame(width: 12, height: 12)
                            .shadow(color: pair.1.color, radius: 6)
                            .offset(x: pair.0)
                            .rotationEffect(.degrees(spin ? 360 : 0) + .degrees(Double(index) * 120))
                            .animation(.linear(duration: 2.4 + Double(index) * 1.1).repeatForever(autoreverses: false), value: spin)
                    }
                    CosmoView(size: 110, pose: .pack)
                }
                .frame(height: 230)

                VStack(spacing: 10) {
                    Text("Packing your capsule")
                        .font(.orbitDisplay(26))
                        .foregroundStyle(Color.textOnDark)
                    Text(lines[lineIndex])
                        .font(.orbitBody(16))
                        .foregroundStyle(Color.textOnDarkMuted)
                        .id(lineIndex)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                removal: .move(edge: .top).combined(with: .opacity)))
                }
                .frame(height: 70)

                if showSkip, let onSkip {
                    Button("Taking a while — I'll arrange it myself", action: onSkip)
                        .font(.orbitHeading(14))
                        .foregroundStyle(Color.skyGlass)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear { spin = true }
        .task {
            try? await Task.sleep(for: .seconds(12))
            withAnimation(.spring) { showSkip = true }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.spring(duration: 0.5)) { lineIndex = (lineIndex + 1) % lines.count }
            }
        }
    }
}

#Preview {
    GroundControlLoadingView(recipientName: "Maya")
}
