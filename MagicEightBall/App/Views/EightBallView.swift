import SwiftUI
import EightBallCore

enum AskPhase: Equatable {
    case idle
    case thinking
    case revealed
}

/// The ball itself: a shaded sphere with the classic die window.
struct EightBallView: View {
    let prediction: Prediction?
    let phase: AskPhase
    let size: CGFloat
    var reduceMotion: Bool = false

    /// Driven by the parent so the wobble stays in sync with the ask sequence.
    var wobble: Double = 0

    private var windowDiameter: CGFloat { size * 0.56 }

    var body: some View {
        ZStack {
            sphere
            windowContent
                .frame(width: windowDiameter, height: windowDiameter)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(reduceMotion ? 0 : wobble))
        .offset(x: reduceMotion ? 0 : wobble * 0.8)
        .shadow(color: .black.opacity(0.6), radius: 30, y: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Sphere

    private var sphere: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(white: 0.26),
                        Color(white: 0.10),
                        Color(white: 0.02)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: size * 0.78
                )
            )
            .overlay(
                // Specular highlight.
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.13
                        )
                    )
                    .frame(width: size * 0.30, height: size * 0.20)
                    .offset(x: -size * 0.19, y: -size * 0.27)
                    .blur(radius: size * 0.015)
            )
            .overlay(
                Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Window

    @ViewBuilder
    private var windowContent: some View {
        switch phase {
        case .idle:
            eightBadge
                .transition(.scale.combined(with: .opacity))
        case .thinking:
            cloudyWindow
                .transition(.opacity)
        case .revealed:
            answerWindow
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private var eightBadge: some View {
        ZStack {
            Circle().fill(.white)
            Text("8")
                .font(.system(size: windowDiameter * 0.62, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .offset(y: -windowDiameter * 0.02)
        }
        .frame(width: windowDiameter * 0.62, height: windowDiameter * 0.62)
    }

    private var cloudyWindow: some View {
        ZStack {
            windowWell
            Text("· · ·")
                .font(.system(size: windowDiameter * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var answerWindow: some View {
        ZStack {
            windowWell

            // The classic 20-sided die face, point down.
            DieTriangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.windowBlue.opacity(0.95),
                            Theme.windowBlue.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: windowDiameter * 0.94, height: windowDiameter * 0.86)
                .overlay(
                    DieTriangle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                        .frame(width: windowDiameter * 0.94, height: windowDiameter * 0.86)
                )

            Text(prediction?.answerText ?? "")
                .font(.system(size: windowDiameter * 0.115, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(5)
                .padding(.horizontal, windowDiameter * 0.14)
                .offset(y: -windowDiameter * 0.04)
        }
    }

    private var windowWell: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(white: 0.06), .black],
                    center: .center,
                    startRadius: 0,
                    endRadius: windowDiameter * 0.6
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle: return "Magic 8 Ball, ready. Shake or tap to ask."
        case .thinking: return "The ball is thinking."
        case .revealed: return prediction?.accessibilityDescription ?? "An answer has appeared."
        }
    }
}

/// Downward-pointing triangle, matching the die visible through the window.
struct DieTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        CosmicBackground()
        EightBallView(
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
