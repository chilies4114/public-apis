import SwiftUI
import EightBallCore

/// Shows where a reading landed on the 0–100% "chance of yes" axis, with the
/// three verdict bands drawn behind it.
///
/// This is the piece that makes the probability scale legible: the marker's
/// position *is* the number shown, and the band it sits in *is* the verdict.
struct LikelihoodBar: View {
    let likelihood: Double
    let sentiment: Sentiment
    var showsMarker: Bool = true
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(likelihood, 0), 1)

            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    band(.negative)
                    band(.noncommittal)
                    band(.affirmative)
                }

                if showsMarker {
                    Capsule()
                        .fill(.white)
                        .frame(width: 4, height: height + 8)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .offset(x: (width - 4) * clamped)
                }
            }
            .frame(height: height + 8)
        }
        .frame(height: height + 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chance of yes")
        .accessibilityValue("\(Int((min(max(likelihood, 0), 1)) * 100)) percent, \(sentiment.displayName)")
    }

    private func band(_ band: Sentiment) -> some View {
        Capsule()
            .fill(Theme.tint(for: band).opacity(band == sentiment ? 0.95 : 0.28))
            .frame(height: height)
    }
}

/// Static preview of a scale's weights — used on the odds screen and the paywall.
struct ScaleWeightBar: View {
    let scale: ProbabilityScale
    var height: CGFloat = 14
    var showsLabels: Bool = true

    var body: some View {
        let parts = scale.displayPercentages

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                HStack(spacing: 2) {
                    segment(.affirmative, fraction: scale.affirmative, width: width)
                    segment(.noncommittal, fraction: scale.noncommittal, width: width)
                    segment(.negative, fraction: scale.negative, width: width)
                }
            }
            .frame(height: height)

            if showsLabels {
                HStack(spacing: 14) {
                    legend(.affirmative, percent: parts.affirmative)
                    legend(.noncommittal, percent: parts.noncommittal)
                    legend(.negative, percent: parts.negative)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Odds: \(parts.affirmative) percent yes, \(parts.noncommittal) percent maybe, \(parts.negative) percent no"
        )
    }

    @ViewBuilder
    private func segment(_ sentiment: Sentiment, fraction: Double, width: CGFloat) -> some View {
        // Zero-weight verdicts collapse entirely rather than leaving a sliver
        // that would imply they can still come up.
        if fraction > 0 {
            Capsule()
                .fill(Theme.tint(for: sentiment))
                .frame(width: max(4, width * fraction - 2))
        }
    }

    private func legend(_ sentiment: Sentiment, percent: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.tint(for: sentiment))
                .frame(width: 8, height: 8)
            Text("\(sentiment.displayName) \(percent)%")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
