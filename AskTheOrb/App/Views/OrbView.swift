import SwiftUI
import OrbCore

enum AskPhase: Equatable {
    case idle
    case thinking
    case revealed
}

/// The orb: a glass sphere with mist moving inside it, and the answer surfacing
/// from within rather than through a window.
///
/// Everything is drawn with SwiftUI shapes and gradients — no image assets — so
/// it stays sharp at any size and the mist can be animated cheaply.
struct OrbView: View {
    let prediction: Prediction?
    let phase: AskPhase
    let size: CGFloat
    var reduceMotion: Bool = false

    /// Driven by the parent so the wobble stays in sync with the ask sequence.
    var wobble: Double = 0

    /// Continuous 0...1 drift used to swirl the mist.
    @State private var drift: Double = 0

    private var glassCore: Color {
        guard phase == .revealed, let prediction else {
            return Color(red: 0.30, green: 0.24, blue: 0.62)
        }
        return Theme.tint(for: prediction.sentiment)
    }

    var body: some View {
        ZStack {
            halo
            glass
            mist
            caustics
            content
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(reduceMotion ? 0 : wobble))
        .offset(x: reduceMotion ? 0 : wobble * 0.8)
        .shadow(color: glassCore.opacity(0.35), radius: 40, y: 16)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                drift = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Layers

    /// Outer glow. Brightens on reveal, tinted by the verdict.
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        glassCore.opacity(phase == .revealed ? 0.55 : 0.30),
                        glassCore.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: size * 0.34,
                    endRadius: size * 0.62
                )
            )
            .scaleEffect(phase == .thinking ? 1.06 : 1.0)
            .animation(
                phase == .thinking && !reduceMotion
                    ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.4),
                value: phase
            )
    }

    /// The sphere body: dark at the centre so text stays legible, luminous at
    /// the rim so it reads as glass rather than a flat disc.
    private var glass: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.06, green: 0.05, blue: 0.16),
                        Color(red: 0.10, green: 0.08, blue: 0.26),
                        glassCore.opacity(0.55)
                    ],
                    center: UnitPoint(x: 0.42, y: 0.40),
                    startRadius: size * 0.04,
                    endRadius: size * 0.52
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.55),
                                glassCore.opacity(0.30),
                                .white.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1, size * 0.006)
                    )
            )
            .frame(width: size * 0.86, height: size * 0.86)
    }

    /// Two slow, blurred blobs that read as smoke curling inside the glass.
    private var mist: some View {
        let angle = drift * 360
        let intensity: Double = {
            switch phase {
            case .idle: return 0.22
            case .thinking: return 0.55
            case .revealed: return 0.30
            }
        }()

        return ZStack {
            Ellipse()
                .fill(glassCore.opacity(intensity))
                .frame(width: size * 0.46, height: size * 0.30)
                .offset(x: -size * 0.10, y: size * 0.08)
                .rotationEffect(.degrees(angle))
                .blur(radius: size * 0.06)

            Ellipse()
                .fill(Color(red: 0.55, green: 0.75, blue: 1.0).opacity(intensity * 0.8))
                .frame(width: size * 0.38, height: size * 0.24)
                .offset(x: size * 0.11, y: -size * 0.06)
                .rotationEffect(.degrees(-angle * 1.4))
                .blur(radius: size * 0.055)
        }
        .frame(width: size * 0.86, height: size * 0.86)
        .clipShape(Circle())
        .animation(.easeInOut(duration: 0.5), value: phase)
    }

    /// Specular highlight plus the small bounce light that sells the glass.
    private var caustics: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.75), .white.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.10
                    )
                )
                .frame(width: size * 0.24, height: size * 0.15)
                .offset(x: -size * 0.17, y: -size * 0.23)
                .blur(radius: size * 0.012)

            Circle()
                .fill(.white.opacity(0.30))
                .frame(width: size * 0.045, height: size * 0.045)
                .offset(x: size * 0.19, y: size * 0.21)
                .blur(radius: size * 0.01)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Contents

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            Image(systemName: "moon.stars.fill")
                .font(.system(size: size * 0.13, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
                .transition(.scale.combined(with: .opacity))

        case .thinking:
            Text("· · ·")
                .font(.system(size: size * 0.13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .transition(.opacity)

        case .revealed:
            Text(prediction?.answerText ?? "")
                .font(.system(size: size * 0.072, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 6)
                .minimumScaleFactor(0.5)
                .lineLimit(5)
                .padding(.horizontal, size * 0.18)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle: return "The orb, ready. Shake or tap to ask."
        case .thinking: return "The orb is thinking."
        case .revealed: return prediction?.accessibilityDescription ?? "An answer has appeared."
        }
    }
}

#Preview {
    ZStack {
        CosmicBackground()
        OrbView(
            prediction: Prediction(
                question: "Will it rain?",
                answerText: "Signs point to yes.",
                sentiment: .affirmative,
                packID: "classic",
                packName: "Classic",
                likelihood: 0.81,
                scale: .classic,
                date: .now,
                variant: 0
            ),
            phase: .revealed,
            size: 300
        )
    }
}
