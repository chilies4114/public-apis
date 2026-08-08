import Foundation

/// How likely each verdict family is to come up.
///
/// Weights are always stored normalised, so `affirmative` reads directly as
/// "the probability this orb says yes". Constructing a scale with garbage
/// input (negatives, all zeros) falls back to an even three-way split rather
/// than trapping — the orb should never be able to crash the app.
public struct ProbabilityScale: Codable, Hashable, Sendable {
    public private(set) var affirmative: Double
    public private(set) var noncommittal: Double
    public private(set) var negative: Double

    public init(affirmative: Double, noncommittal: Double, negative: Double) {
        let a = affirmative.isFinite ? max(0, affirmative) : 0
        let n = noncommittal.isFinite ? max(0, noncommittal) : 0
        let g = negative.isFinite ? max(0, negative) : 0
        let total = a + n + g

        if total <= 0 {
            self.affirmative = 1.0 / 3.0
            self.noncommittal = 1.0 / 3.0
            self.negative = 1.0 / 3.0
        } else {
            self.affirmative = a / total
            self.noncommittal = n / total
            self.negative = g / total
        }
    }

    public func weight(for sentiment: Sentiment) -> Double {
        switch sentiment {
        case .affirmative: return affirmative
        case .noncommittal: return noncommittal
        case .negative: return negative
        }
    }

    /// Percentages rounded for display, guaranteed to sum to exactly 100.
    ///
    /// Rounding each weight independently can produce 99 or 101, which looks
    /// broken next to a slider, so the largest share absorbs the remainder.
    public var displayPercentages: (affirmative: Int, noncommittal: Int, negative: Int) {
        var values = [
            (Sentiment.affirmative, Int((affirmative * 100).rounded())),
            (Sentiment.noncommittal, Int((noncommittal * 100).rounded())),
            (Sentiment.negative, Int((negative * 100).rounded()))
        ]
        let drift = 100 - values.reduce(0) { $0 + $1.1 }
        if drift != 0, let index = values.indices.max(by: { values[$0].1 < values[$1].1 }) {
            values[index].1 += drift
        }
        return (values[0].1, values[1].1, values[2].1)
    }

    /// The classic toy: 10 affirmative, 5 non-committal, 5 negative out of 20.
    public static let classic = ProbabilityScale(affirmative: 10, noncommittal: 5, negative: 5)
}

/// A named, one-tap probability scale.
public struct ScalePreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let scale: ProbabilityScale
    public let requiresPro: Bool

    public init(id: String, name: String, detail: String, scale: ProbabilityScale, requiresPro: Bool) {
        self.id = id
        self.name = name
        self.detail = detail
        self.scale = scale
        self.requiresPro = requiresPro
    }

    public static let classic = ScalePreset(
        id: "classic",
        name: "Classic",
        detail: "The original 20-sided die: 10 yes, 5 maybe, 5 no.",
        scale: .classic,
        requiresPro: false
    )

    public static let all: [ScalePreset] = [
        .classic,
        ScalePreset(
            id: "sunny",
            name: "Sunny Side",
            detail: "Stacked in your favour. Seven yeses in ten.",
            scale: ProbabilityScale(affirmative: 70, noncommittal: 20, negative: 10),
            requiresPro: true
        ),
        ScalePreset(
            id: "realist",
            name: "Realist",
            detail: "A dead-even three-way split. No thumb on the scale.",
            scale: ProbabilityScale(affirmative: 1, noncommittal: 1, negative: 1),
            requiresPro: true
        ),
        ScalePreset(
            id: "coinflip",
            name: "Coin Flip",
            detail: "Yes or no, nothing in between.",
            scale: ProbabilityScale(affirmative: 50, noncommittal: 0, negative: 50),
            requiresPro: true
        ),
        ScalePreset(
            id: "fog",
            name: "Cosmic Fog",
            detail: "The orb is mostly undecided today.",
            scale: ProbabilityScale(affirmative: 25, noncommittal: 50, negative: 25),
            requiresPro: true
        ),
        ScalePreset(
            id: "hardtruth",
            name: "Hard Truth",
            detail: "A pessimist's oracle. Brace yourself.",
            scale: ProbabilityScale(affirmative: 20, noncommittal: 25, negative: 55),
            requiresPro: true
        )
    ]

    public static func preset(withID id: String) -> ScalePreset? {
        all.first { $0.id == id }
    }
}
