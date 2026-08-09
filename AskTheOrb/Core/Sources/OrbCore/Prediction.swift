import Foundation

/// One reading from the orb, in a form that survives pack changes.
///
/// The answer text is copied in rather than referenced by ID so history entries
/// keep reading correctly even if the user later loses access to a Pro pack.
/// The odds measured at the time of the draw are stored alongside it, so a
/// reading always carries the true chance that produced it.
public struct Prediction: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let question: String
    public let answerText: String
    public let sentiment: Sentiment
    public let packID: String
    public let packName: String
    /// The composition of the pool this answer was drawn from.
    public let odds: OddsMeasurement
    public let date: Date
    /// Which re-ask this was for the same question on the same day. 0 == first.
    public let variant: Int

    public init(
        id: UUID = UUID(),
        question: String,
        answerText: String,
        sentiment: Sentiment,
        packID: String,
        packName: String,
        odds: OddsMeasurement,
        date: Date,
        variant: Int
    ) {
        self.id = id
        self.question = question
        self.answerText = answerText
        self.sentiment = sentiment
        self.packID = packID
        self.packName = packName
        self.odds = odds
        self.date = date
        self.variant = variant
    }

    /// "10 in 20" — the chance this verdict had before it was drawn.
    public var chanceDescription: String {
        odds.chanceDescription(of: sentiment)
    }

    /// The chance of a yes in the pool this was drawn from, as a percentage.
    public var yesChancePercent: Int {
        odds.percentages.affirmative
    }

    /// Copy for VoiceOver, which should never have to read a bare ratio.
    public var accessibilityDescription: String {
        let verdict = sentiment.displayName
        let chance = "\(verdict) had a \(chanceDescription) chance."
        if question.isEmpty {
            return "\(verdict). \(answerText) \(chance)"
        }
        return "You asked: \(question). \(verdict). \(answerText) \(chance)"
    }
}
