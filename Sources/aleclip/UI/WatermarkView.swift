import SwiftUI
import AppKit

// MARK: - Colorful Logo Watermark View (Clipale Signature Brand)

public struct WatermarkView: View {
    @Environment(\.colorScheme) private var colorScheme

    public var isCompact: Bool = false

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    // Vibrant spectrum gradient: Cyan -> Azure -> Mint -> Emerald -> Lime -> Gold -> Tangerine
    public static var spectrumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.00, green: 0.88, blue: 1.00), // Electric Cyan
                Color(red: 0.05, green: 0.52, blue: 1.00), // Cobalt Azure
                Color(red: 0.00, green: 0.90, blue: 0.65), // Neon Mint
                Color(red: 0.12, green: 0.82, blue: 0.38), // Emerald Green
                Color(red: 0.64, green: 0.90, blue: 0.10), // Electric Lime
                Color(red: 1.00, green: 0.78, blue: 0.00), // Sunburst Gold
                Color(red: 1.00, green: 0.44, blue: 0.00)  // Sunset Tangerine Orange
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public var body: some View {
        let isDark = colorScheme == .dark
        let textOpacity = isDark ? 0.75 : 0.60
        let glowOpacity = isDark ? 0.42 : 0.25

        if isCompact {
            // Compact Brand Mark for Header Bar
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Self.spectrumGradient)
                        .frame(width: 26, height: 26)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)

                    Image(systemName: "paperclip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(-45))
                }

                HStack(spacing: 3) {
                    Text("Ale")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Clip")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Self.spectrumGradient)
                }
            }
        } else {
            // Full Radiant Watermark for Background / Empty State
            HStack(spacing: 16) {
                // Stylized Logo Emblem Badge
                ZStack {
                    Circle()
                        .fill(Self.spectrumGradient)
                        .frame(width: 58, height: 58)
                        .blur(radius: 16)
                        .opacity(glowOpacity)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.00, green: 0.88, blue: 1.00).opacity(isDark ? 0.24 : 0.15),
                                    Color(red: 1.00, green: 0.44, blue: 0.00).opacity(isDark ? 0.24 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Self.spectrumGradient, lineWidth: 2)
                                .opacity(textOpacity + 0.25)
                        )

                    Image(systemName: "paperclip")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Self.spectrumGradient)
                        .rotationEffect(.degrees(-45))
                        .opacity(textOpacity + 0.3)
                }

                // Wordmark: "ALE" with glowing gradient & "CLIP" badge
                VStack(alignment: .leading, spacing: -2) {
                    ZStack(alignment: .leading) {
                        Text("ALE")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(Self.spectrumGradient)
                            .blur(radius: 14)
                            .opacity(glowOpacity)

                        Text("ALE")
                            .font(.system(size: 50, weight: .black, design: .rounded))
                            .foregroundStyle(Self.spectrumGradient)
                            .opacity(textOpacity + 0.35)
                    }

                    HStack(spacing: 6) {
                        Text("CLIP")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(3.5)
                            .foregroundStyle(Self.spectrumGradient)
                            .opacity(textOpacity + 0.25)

                        Capsule()
                            .fill(Self.spectrumGradient)
                            .frame(width: 26, height: 2.5)
                            .opacity(textOpacity + 0.25)
                    }
                    .padding(.leading, 2)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
