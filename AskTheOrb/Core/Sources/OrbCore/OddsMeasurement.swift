import Foundation

/// The measured composition of an answer pool.
///
/// This replaces the old settable "probability scale". The odds are no longer a
/// dial anyone can turn — they are a *count* of what is actually in the pool the
/// orb draws from. Ten of the twenty classic answers say yes, so the chance of
/// yes is 10 in 20. Not a claim, not a setting: a measurement.
///
/// Because `Oracle` draws one answer uniformly from that pool, this ratio *is*
/// the mechanism rather than a description of it. There is no separate weighting
/// step that could disagree with the number on screen.
public struct OddsMeasurement: Equatable, Codable, Sendable {
    public let affirmative: Int
    public let noncommittal: Int
    public let negative: Int

    public init(affirmative: Int, noncommittal: Int, negative: Int) {
        self.affirmative = max(0, affirmative)
        self.noncommittal = max(0, noncommittal)
        self.negative = max(0, negative)
    }

    public var total: Int { affirmative + noncommittal + negative }

    public func count(of sentiment: Sentiment) -> Int {
        switch sentiment {
        case .affirmative: return affirmative
        case .noncommittal: return noncommittal
        case .negative: return negative
        }
    }

    /// Exact probability of a verdict: its share of the pool.
    public func probability(of sentiment: Sentiment) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(of: sentiment)) / Double(total)
    }

    /// "10 in 20" — the phrasing that makes the measurement legible without
    /// anyone having to trust a percentage.
    public func chanceDescription(of sentiment: Sentiment) -> String {
        "\(count(of: sentiment)) in \(total)"
    }

    /// Rounded shares, guaranteed to sum to exactly 100.
    ///
    /// Rounding each independently can produce 99 or 101, which looks broken
    /// next to a stated ratio, so the largest share absorbs the remainder.
    public var percentages: (affirmative: Int, noncommittal: Int, negative: Int) {
        guard total > 0 else { return (0, 0, 0) }
        var values = [
            Int((probability(of: .affirmative) * 100).rounded()),
            Int((probability(of: .noncommittal) * 100).rounded()),
            Int((probability(of: .negative) * 100).rounded()),
        ]
        let drift = 100 - values.reduce(0, +)
        if drift != 0, let biggest = values.indices.max(by: { values[$0] < values[$1] }) {
            values[biggest] += drift
        }
        return (values[0], values[1], values[2])
    }

    /// The composition in lowest terms — 10:5:5 reads better as "2 : 1 : 1".
    public var reducedRatio: (affirmative: Int, noncommittal: Int, negative: Int) {
        let divisor = [affirmative, noncommittal, negative].reduce(0) { greatestCommonDivisor($0, $1) }
        guard divisor > 1 else { return (affirmative, noncommittal, negative) }
        return (affirmative / divisor, noncommittal / divisor, negative / divisor)
    }

    public var ratioDescription: String {
        let r = reducedRatio
        return "\(r.affirmative) : \(r.noncommittal) : \(r.negative)"
    }

    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    // MARK: - Measuring

    /// Counts the verdicts across the packs the orb is allowed to draw from.
    public static func measure(packs: [AnswerPack], allowedPackIDs: Set<String>) -> OddsMeasurement {
        let usable = packs.filter { allowedPackIDs.contains($0.id) }
        let pool = usable.isEmpty ? [AnswerCatalog.classic] : usable

        var counts: [Sentiment: Int] = [:]
        for pack in pool {
            for answer in pack.answers {
                counts[answer.sentiment, default: 0] += 1
            }
        }
        return OddsMeasurement(
            affirmative: counts[.affirmative, default: 0],
            noncommittal: counts[.noncommittal, default: 0],
            negative: counts[.negative, default: 0]
        )
    }

    /// What a single pack contributes — the shape every pack must share.
    public static let perPack = OddsMeasurement(affirmative: 10, noncommittal: 5, negative: 5)
}

/// A tally of verdicts the user has actually received.
///
/// The designed odds say what *should* happen. This says what *did*. Over a
/// short run the two will visibly disagree, which is the honest and interesting
/// thing about probability — and the reason this is shown with its sample size
/// rather than as a bare percentage.
public struct ObservedOdds: Equatable, Sendable {
    public let affirmative: Int
    public let noncommittal: Int
    public let negative: Int

    public init(affirmative: Int = 0, noncommittal: Int = 0, negative: Int = 0) {
        self.affirmative = affirmative
        self.noncommittal = noncommittal
        self.negative = negative
    }

    public init(sentiments: [Sentiment]) {
        var counts: [Sentiment: Int] = [:]
        for sentiment in sentiments { counts[sentiment, default: 0] += 1 }
        self.init(
            affirmative: counts[.affirmative, default: 0],
            noncommittal: counts[.noncommittal, default: 0],
            negative: counts[.negative, default: 0]
        )
    }

    public var total: Int { affirmative + noncommittal + negative }

    public func count(of sentiment: Sentiment) -> Int {
        switch sentiment {
        case .affirmative: return affirmative
        case .noncommittal: return noncommittal
        case .negative: return negative
        }
    }

    public func rate(of sentiment: Sentiment) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(of: sentiment)) / Double(total)
    }

    /// How far the observed yes-rate sits from the designed one, in percentage
    /// points. Signed, so the UI can say "3 points above expected".
    public func drift(from expected: OddsMeasurement, for sentiment: Sentiment) -> Double {
        guard total > 0 else { return 0 }
        return (rate(of: sentiment) - expected.probability(of: sentiment)) * 100
    }

    /// Below this, the observed rate is mostly noise and shouldn't be read as a
    /// trend. Stated in the UI rather than hidden, because "your yes-rate is
    /// 33%" after three questions is a meaningless number presented as a fact.
    public static let meaningfulSampleSize = 20

    public var isMeaningful: Bool { total >= Self.meaningfulSampleSize }

    /// Standard error of the observed rate, as percentage points. Used to say
    /// how wide the expected wobble is at this sample size.
    public func standardErrorPoints(for sentiment: Sentiment, expected: OddsMeasurement) -> Double {
        guard total > 0 else { return 0 }
        let p = expected.probability(of: sentiment)
        return (p * (1 - p) / Double(total)).squareRoot() * 100
    }
}
