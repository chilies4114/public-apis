import Foundation

/// Turns a question into a prediction.
///
/// The draw is a single uniform pick from every answer the user has unlocked.
/// There is no weighting step and nothing to configure: the chance of a yes is
/// the number of yes answers divided by the size of the pool, and that is the
/// same number the app puts on screen.
///
/// Because every shipped pack has the identical 10/5/5 composition, the measured
/// odds come out at 10 : 5 : 5 no matter which packs are switched on. Buying a
/// pack changes the orb's vocabulary and provably not its luck.
public struct Oracle: Sendable {
    public let packs: [AnswerPack]

    public init(packs: [AnswerPack] = AnswerCatalog.all) {
        self.packs = packs
    }

    // MARK: - Deterministic entry point

    /// Ask the orb. The same question on the same day produces the same answer.
    ///
    /// - Parameter variant: bump this to force a genuinely new draw for a
    ///   question already asked today (the Pro "ask again" affordance).
    public func predict(
        question: String,
        allowedPackIDs: Set<String>,
        date: Date = Date(),
        variant: Int = 0,
        calendar: Calendar = .current
    ) -> Prediction {
        var generator = SeededGenerator(
            seed: Oracle.seed(question: question, date: date, variant: variant, calendar: calendar)
        )
        return predict(
            question: question,
            allowedPackIDs: allowedPackIDs,
            date: date,
            variant: variant,
            using: &generator
        )
    }

    // MARK: - Injectable-randomness entry point

    public func predict<G: RandomNumberGenerator>(
        question: String,
        allowedPackIDs: Set<String>,
        date: Date = Date(),
        variant: Int = 0,
        using generator: inout G
    ) -> Prediction {
        let pool = answerPool(allowedPackIDs: allowedPackIDs)
        let answer = pool.randomElement(using: &generator) ?? Oracle.fallbackAnswer
        let packName = packs.first { $0.id == answer.packID }?.name ?? AnswerCatalog.classic.name

        return Prediction(
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            answerText: answer.text,
            sentiment: answer.sentiment,
            packID: answer.packID,
            packName: packName,
            odds: OddsMeasurement.measure(packs: packs, allowedPackIDs: allowedPackIDs),
            date: date,
            variant: variant
        )
    }

    // MARK: - The pool

    /// Every answer the orb may draw, flattened.
    ///
    /// A user can end up with no usable packs (all deselected, or a lapsed
    /// subscription mid-session). Falling back to Classic keeps the orb
    /// answering — and keeps the measured odds at 10/5/5 — instead of
    /// dead-ending on an empty pool.
    func answerPool(allowedPackIDs: Set<String>) -> [Answer] {
        let usable = packs.filter { allowedPackIDs.contains($0.id) }
        let pool = usable.isEmpty ? [AnswerCatalog.classic] : usable
        return pool.flatMap(\.answers)
    }

    static let fallbackAnswer = Answer(
        id: "fallback.affirmative",
        text: "Ask again later.",
        sentiment: .noncommittal,
        packID: AnswerCatalog.classicPackID
    )

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

    static func seed(question: String, date: Date, variant: Int, calendar: Calendar) -> UInt64 {
        let day = calendar.startOfDay(for: date)
        let dayIndex = Int(day.timeIntervalSinceReferenceDate / 86_400)
        return FNV1a.hash("\(normalize(question))|\(dayIndex)|\(variant)")
    }
}
