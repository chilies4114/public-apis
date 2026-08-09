import SwiftUI
import OrbCore

/// The pool's composition as a bar, with one verdict optionally called out.
///
/// The widths are the counts. Nothing here is a setting or an estimate — the
/// green segment is literally how many of the answers say yes.
struct OddsBar: View {
    let odds: OddsMeasurement
    /// Highlight the verdict that was drawn, dimming the rest.
    var emphasising: Sentiment?
    var height: CGFloat = 14
    var showsLabels: Bool = true

    var body: some View {
        let parts = odds.percentages

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    segment(.affirmative, width: proxy.size.width)
                    segment(.noncommittal, width: proxy.size.width)
                    segment(.negative, width: proxy.size.width)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Odds")
        .accessibilityValue(
            "\(odds.affirmative) yes, \(odds.noncommittal) maybe, \(odds.negative) no, out of \(odds.total)"
        )
    }

    @ViewBuilder
    private func segment(_ sentiment: Sentiment, width: CGFloat) -> some View {
        let share = odds.probability(of: sentiment)
        if share > 0 {
            Capsule()
                .fill(Theme.tint(for: sentiment))
                .opacity(emphasising == nil || emphasising == sentiment ? 1 : 0.3)
                .frame(width: max(4, width * share - 3))
        }
    }

    private func legend(_ sentiment: Sentiment, percent: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.tint(for: sentiment))
                .frame(width: 8, height: 8)
            Text("\(sentiment.displayName) \(percent)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

/// Designed odds versus what the user actually got, drawn as two stacked bars.
///
/// The point of showing both is that they *don't* match on small samples, and
/// that this is normal rather than a bug — which is why the sample size and the
/// expected wobble are stated rather than buried.
struct ObservedComparison: View {
    let expected: OddsMeasurement
    let observed: ObservedOdds

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(
                title: "By design",
                caption: "\(expected.affirmative) of \(expected.total) answers say yes",
                bars: expected.percentages
            )

            if observed.total > 0 {
                row(
                    title: "What you got",
                    caption: "over \(observed.total) reading\(observed.total == 1 ? "" : "s")",
                    bars: (
                        Int((observed.rate(of: .affirmative) * 100).rounded()),
                        Int((observed.rate(of: .noncommittal) * 100).rounded()),
                        Int((observed.rate(of: .negative) * 100).rounded())
                    )
                )

                Text(driftSentence)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ask a few questions and your own results will appear here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func row(title: String, caption: String, bars: (Int, Int, Int)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            GeometryReader { proxy in
                HStack(spacing: 3) {
                    bar(.affirmative, percent: bars.0, width: proxy.size.width)
                    bar(.noncommittal, percent: bars.1, width: proxy.size.width)
                    bar(.negative, percent: bars.2, width: proxy.size.width)
                }
            }
            .frame(height: 14)

            HStack(spacing: 14) {
                Text("Yes \(bars.0)%")
                Text("Maybe \(bars.1)%")
                Text("No \(bars.2)%")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private func bar(_ sentiment: Sentiment, percent: Int, width: CGFloat) -> some View {
        if percent > 0 {
            Capsule()
                .fill(Theme.tint(for: sentiment))
                .frame(width: max(4, width * Double(percent) / 100 - 3))
        }
    }

    private var driftSentence: String {
        let drift = observed.drift(from: expected, for: .affirmative)
        let error = observed.standardErrorPoints(for: .affirmative, expected: expected)
        let points = abs(drift).rounded()

        guard observed.isMeaningful else {
            return "That's only \(observed.total) reading\(observed.total == 1 ? "" : "s"). Short runs wander a long way from the odds — come back after \(ObservedOdds.meaningfulSampleSize) or so before reading anything into it."
        }

        let direction = drift >= 0 ? "above" : "below"
        let expectedWobble = Int(error.rounded())

        if points <= error {
            return "Your yes-rate is \(Int(points)) point\(points == 1 ? "" : "s") \(direction) the designed rate — well inside the ±\(expectedWobble) points you'd expect from chance alone at this sample size."
        }
        return "Your yes-rate is \(Int(points)) point\(points == 1 ? "" : "s") \(direction) the designed rate. At \(observed.total) readings, chance alone typically moves it about ±\(expectedWobble) points."
    }
}
