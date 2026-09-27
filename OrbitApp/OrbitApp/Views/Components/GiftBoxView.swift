import SwiftUI

/// The capsule package, drawn (not an image) so it can take any OrbitHue
/// and so the lid can fly off during the opening burst. Shaded as a lit
/// left face / shadowed right face with a highlighted lid edge and a soft
/// contact shadow, matching the shape of Assets.xcassets/gift.
struct GiftBoxView: View {
    var hue: Color
    var size: CGFloat
    /// 0 = closed, 1 = lid fully blown off.
    var lidProgress: CGFloat = 0
    var showsShadow = true

    private var bodyWidth: CGFloat { size }
    private var bodyHeight: CGFloat { size * 0.74 }
    private var lidHeight: CGFloat { size * 0.24 }

    var body: some View {
        VStack(spacing: 0) {
            lid
                .offset(x: lidProgress * size * 0.9, y: -lidProgress * size * 1.3)
                .rotationEffect(.degrees(Double(lidProgress) * 38), anchor: .bottomTrailing)
                .opacity(1 - Double(max(0, lidProgress - 0.75)) * 4)
                .zIndex(1)
            boxBody
        }
        .background(alignment: .bottom) {
            if showsShadow {
                Ellipse()
                    .fill(.black.opacity(0.35))
                    .frame(width: size * 1.1, height: size * 0.16)
                    .blur(radius: size * 0.05)
                    .offset(y: size * 0.07)
            }
        }
        .frame(width: size * 1.1, height: bodyHeight + lidHeight + size * 0.3, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private var boxBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: hue.lightened(by: 0.22), location: 0),
                    .init(color: hue.lightened(by: 0.12), location: 0.5),
                    .init(color: hue, location: 0.5),          // style-sheet two-tone split…
                    .init(color: hue.darkened(by: 0.18), location: 1), // …with falloff for depth
                ], startPoint: .leading, endPoint: .trailing))
            // Top of the body sits in the lid's shadow.
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(LinearGradient(colors: [.black.opacity(0.22), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.3)))
            ribbonBand(vertical: true)
        }
        .frame(width: bodyWidth, height: bodyHeight)
    }

    private var lid: some View {
        ZStack(alignment: .bottom) {
            bow.offset(y: -lidHeight * 0.72)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(LinearGradient(colors: [hue.lightened(by: 0.3), hue.lightened(by: 0.05), hue.darkened(by: 0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                // Lit top edge.
                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center),
                                  lineWidth: size * 0.02)
                ribbonBand(vertical: true)
            }
            .frame(width: size * 1.08, height: lidHeight)
            .shadow(color: .black.opacity(0.25), radius: size * 0.02, y: size * 0.02)
        }
    }

    private func ribbonBand(vertical: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [.white, Color.navSurfaceLight, Color.cloudGray.opacity(0.9)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: size * 0.16)
    }

    private var bow: some View {
        HStack(spacing: -size * 0.04) {
            loop.rotationEffect(.degrees(-28))
            loop.scaleEffect(x: -1).rotationEffect(.degrees(28))
        }
        .overlay {
            Circle()
                .fill(RadialGradient(colors: [.white, Color.cloudGray], center: .topLeading, startRadius: 0, endRadius: size * 0.1))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(y: size * 0.05)
        }
    }

    private var loop: some View {
        Ellipse()
            .fill(RadialGradient(colors: [.white, Color.navSurfaceLight, Color.cloudGray],
                                 center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.2))
            .overlay(Ellipse().fill(Color.cloudGray.opacity(0.6)).frame(width: size * 0.09, height: size * 0.05))
            .frame(width: size * 0.3, height: size * 0.2)
    }
}

#Preview {
    ZStack {
        Color.spaceDeep.ignoresSafeArea()
        HStack(spacing: 24) {
            GiftBoxView(hue: .orbitMagenta, size: 110)
            GiftBoxView(hue: .orbitSeafoam, size: 80, lidProgress: 0.5)
            GiftBoxView(hue: .orbitGold, size: 60)
        }
    }
}
