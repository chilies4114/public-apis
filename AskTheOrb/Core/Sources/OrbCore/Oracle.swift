import Foundation

/// Turns a question plus a probability scale into a prediction.
///
/// The draw happens in two steps that are deliberately kept separate:
///
/// 1. A likelihood in `0...1` is sampled such that it lands in the affirmative
///    band exactly `scale.affirmative` of the time (and likewise for the other
///    two). This is the *only* place odds are decided.
/// 2. The wording is picked uniformly from the answers of that verdict in the
///    packs the user has unlocked.
///
/// Because step 2 can't influence step 1, buying a pack changes the voice of
/// the orb but never its luck.
public struct Oracle: Sendable {
    public let packs: [AnswerPack]

    public init(packs: [AnswerPack] = AnswerCatalog.all) {
        self.packs = packs
    }

    // MARK: - Deterministic entry point

    /// Ask the orb. The same question, scale and day produce the same answer.
    ///
    /// - Parameter variant: bump this to force a genuinely new draw for a
    ///   question already asked today (the Pro "ask again" affordance).
    public func predict(
        question: String,
        scale: ProbabilityScale,
        allowedPackIDs: Set<String>,
        date: Date = Date(),
        variant: Int = 0,
        calendar: Calendar = .current
    ) -> Prediction {
        var generator = SeededGenerator(
            seed: Oracle.seed(
                question: question,
                scale: scale,
                date: date,
                variant: variant,
                calendar: calendar
            )
        )
        return predict(
            question: question,
            scale: scale,
            allowedPackIDs: allowedPackIDs,
            date: date,
            variant: variant,
            using: &generator
        )
    }

    // MARK: - Injectable-randomness entry point

    public func predict<G: RandomNumberGenerator>(
        question: String,
        scale: ProbabilityScale,
        allowedPackIDs: Set<String>,
        date: Date = Date(),
        variant: Int = 0,
        using generator: inout G
    ) -> Prediction {
        let (sentiment, likelihood) = Oracle.draw(scale: scale, using: &generator)
        let pool = answers(sentiment: sentiment, allowedPackIDs: allowedPackIDs)
        let answer = pool.randomElement(using: &generator) ?? Oracle.fallbackAnswer(for: sentiment)
        let packName = packs.first { $0.id == answer.packID }?.name ?? "Classic"

        return Prediction(
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            answerText: answer.text,
            sentiment: sentiment,
            packID: answer.packID,
            packName: packName,
            likelihood: likelihood,
            scale: scale,
            date: date,
            variant: variant
        )
    }

    // MARK: - The draw

    /// Samples a verdict and a likelihood that agrees with it.
    ///
    /// A uniform draw is split across the three weights, then rescaled into that
    /// verdict's fixed third of the 0...1 axis. The result: `P(affirmative)`
    /// equals `scale.affirmative` exactly, while the displayed percentage can
    /// never contradict the verdict.
    static func draw<G: RandomNumberGenerator>(
        scale: ProbabilityScale,
        using generator: inout G
    ) -> (sentiment: Sentiment, likelihood: Double) {
        let roll = Double.random(in: 0..<1, using: &generator)

        let sentiment: Sentiment
        let positionInWeight: Double

        if roll < scale.negative {
            sentiment = .negative
            positionInWeight = scale.negative > 0 ? roll / scale.negative : 0
        } else if roll < scale.negative + scale.noncommittal {
            sentiment = .noncommittal
            positionInWeight = scale.noncommittal > 0 ? (roll - scale.negative) / scale.noncommittal : 0
        } else {
            sentiment = .affirmative
            let consumed = scale.negative + scale.noncommittal
            positionInWeight = scale.affirmative > 0 ? (roll - consumed) / scale.affirmative : 0
        }

        let band = sentiment.likelihoodBand
        let width = band.upperBound - band.lowerBound
        let likelihood = band.lowerBound + min(max(positionInWeight, 0), 1) * width

        return (sentiment, min(max(likelihood, 0), 1))
    }

    // MARK: - Answer selection

    func answers(sentiment: Sentiment, allowedPackIDs: Set<String>) -> [Answer] {
        let pool = packs
            .filter { allowedPackIDs.contains($0.id) }
            .flatMap { $0.answers(for: sentiment) }

        // A user can end up with no usable packs (all deselected, or a lapsed
        // subscription mid-session). Falling back to Classic keeps the orb
        // answering instead of dead-ending on an empty pool.
        guard pool.isEmpty else { return pool }
        return AnswerCatalog.classic.answers(for: sentiment)
    }

    static func fallbackAnswer(for sentiment: Sentiment) -> Answer {
        let text: String
        switch sentiment {
        case .affirmative: text = "Yes."
        case .noncommittal: text = "Ask again later."
        case .negative: text = "My reply is no."
        }
        return Answer(
            id: "fallback.\(sentiment.rawValue)",
            text: text,
            sentiment: sentiment,
            packID: AnswerCatalog.classicPackID
        )
    }

    // MARK: - Seeding

    /// Normalises a question so "Will it rain?" and " will  it rain " are the
    /// same question to the orb.
    static func normalize(_ question: String) -> String {
        let lowered = question.lowercased()
        let stripped = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(stripped)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    static func seed(
        question: String,
        scale: ProbabilityScale,
        date: Date,
        variant: Int,
        calendar: Calendar
    ) -> UInt64 {
        let day = calendar.startOfDay(for: date)
        let dayIndex = Int(day.timeIntervalSinceReferenceDate / 86_400)
        let odds = Int((scale.affirmative * 1000).rounded())
        let hedge = Int((scale.noncommittal * 1000).rounded())
        let key = "\(normalize(question))|\(dayIndex)|\(odds)|\(hedge)|\(variant)"
        return FNV1a.hash(key)
    }
}
