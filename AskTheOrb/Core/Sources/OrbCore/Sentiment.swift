import Foundation

/// The three verdict families the orb can return.
///
/// Every answer in every pack belongs to exactly one of these, which is what
/// lets a single probability scale drive packs with different wording.
public enum Sentiment: String, Codable, CaseIterable, Sendable {
    case negative
    case noncommittal
    case affirmative

    public var displayName: String {
        switch self {
        case .affirmative: return "Yes"
        case .noncommittal: return "Maybe"
        case .negative: return "No"
        }
    }

    public var symbolName: String {
        switch self {
        case .affirmative: return "checkmark.seal.fill"
        case .noncommittal: return "questionmark.diamond.fill"
        case .negative: return "xmark.seal.fill"
        }
    }

    /// The slice of the 0...1 likelihood axis this verdict occupies.
    ///
    /// The three bands tile `0...1` evenly, so a displayed "chance of yes"
    /// percentage can never contradict the verdict shown next to it: a `No`
    /// always reads under 33%, a `Yes` always reads over 67%.
    public var likelihoodBand: Range<Double> {
        switch self {
        case .negative: return 0.0 ..< (1.0 / 3.0)
        case .noncommittal: return (1.0 / 3.0) ..< (2.0 / 3.0)
        case .affirmative: return (2.0 / 3.0) ..< 1.0
        }
    }

    /// The verdict whose band contains `likelihood`.
    public static func forLikelihood(_ likelihood: Double) -> Sentiment {
        let clamped = min(max(likelihood, 0), 1)
        if clamped < 1.0 / 3.0 { return .negative }
        if clamped < 2.0 / 3.0 { return .noncommittal }
        return .affirmative
    }
}
