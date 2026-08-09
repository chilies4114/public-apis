import Foundation

/// The three verdict families the orb can return.
///
/// Every answer in every pack belongs to exactly one of these, which is what
/// lets every pack share one measured set of odds while wording differs.
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
}
