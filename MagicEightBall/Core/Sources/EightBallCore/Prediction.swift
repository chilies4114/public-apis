import Foundation

/// One reading from the ball, in a form that survives pack changes.
///
/// The answer text is copied in rather than referenced by ID so history entries
/// keep reading correctly even if the user later loses access to a Pro pack.
public struct Prediction: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let question: String
    public let answerText: String
    public let sentiment: Sentiment
    public let packID: String
    public let packName: String
    /// Probability of a positive outcome, 0...1. Always inside `sentiment.likelihoodBand`.
    public let likelihood: Double
    public let scale: ProbabilityScale
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
        likelihood: Double,
        scale: ProbabilityScale,
        date: Date,
        variant: Int
    ) {
        self.id = id
        self.question = question
        self.answerText = answerText
        self.sentiment = sentiment
        self.packID = packID
        self.packName = packName
        self.likelihood = likelihood
        self.scale = scale
        self.date = date
        self.variant = variant
    }

    /// The headline number: "68% chance of yes".
    public var likelihoodPercent: Int {
        Int((min(max(likelihood, 0), 1) * 100).rounded())
    }

    /// Copy for VoiceOver, which should never have to read a bare percentage.
    public var accessibilityDescription: String {
        let verdict = sentiment.displayName
        if question.isEmpty {
            return "\(verdict). \(answerText) \(likelihoodPercent) percent chance of yes."
        }
        return "You asked: \(question). \(verdict). \(answerText) \(likelihoodPercent) percent chance of yes."
    }
}
