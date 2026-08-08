import Foundation

/// Everything the paid tier unlocks, in one list the paywall and the gates share.
public enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case unlimitedAsks
    case allAnswerPacks
    case customProbability
    case askAgain
    case fullHistory
    case insights

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unlimitedAsks: return "Unlimited questions"
        case .allAnswerPacks: return "Every answer pack"
        case .customProbability: return "Tune the odds"
        case .askAgain: return "Ask again"
        case .fullHistory: return "Full history"
        case .insights: return "Insights"
        }
    }

    public var detail: String {
        switch self {
        case .unlimitedAsks:
            return "Ask as much as you like. No daily cap, ever."
        case .allAnswerPacks:
            return "Cosmic, Deadpan, Fortune Cookie, Boardroom and High Seas — mix and match."
        case .customProbability:
            return "Set the exact odds of yes, maybe and no with a custom scale."
        case .askAgain:
            return "Re-roll a question you already asked today."
        case .fullHistory:
            return "Keep every reading, search it, and add your own notes."
        case .insights:
            return "See how the ball has actually been leaning over time."
        }
    }

    public var symbolName: String {
        switch self {
        case .unlimitedAsks: return "infinity"
        case .allAnswerPacks: return "square.stack.3d.up.fill"
        case .customProbability: return "slider.horizontal.3"
        case .askAgain: return "arrow.clockwise"
        case .fullHistory: return "clock.arrow.circlepath"
        case .insights: return "chart.bar.fill"
        }
    }
}

/// What the free tier gets. Kept in one place so the paywall copy, the gates and
/// the tests can't drift apart.
public enum FreeTier {
    public static let dailyQuestionLimit = 5
    public static let historyLimit = 3
    public static let packIDs = AnswerCatalog.freePackIDs
    public static let preset = ScalePreset.classic
}

/// Tracks how many questions have been asked today.
///
/// Stored as a day index rather than a `Date` so a rollover is a plain integer
/// comparison — no time-zone arithmetic at read time, and trivially testable.
public struct AskAllowance: Codable, Equatable, Sendable {
    public private(set) var dayIndex: Int
    public private(set) var used: Int

    public init(dayIndex: Int = 0, used: Int = 0) {
        self.dayIndex = dayIndex
        self.used = max(0, used)
    }

    static func dayIndex(for date: Date, calendar: Calendar) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400)
    }

    /// Rolls the counter over if the day changed since the last ask.
    private mutating func rollIfNeeded(to today: Int) {
        if dayIndex != today {
            dayIndex = today
            used = 0
        }
    }

    /// Questions left today, or `nil` when unlimited.
    public func remaining(isPro: Bool, on date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard !isPro else { return nil }
        let today = Self.dayIndex(for: date, calendar: calendar)
        guard today == dayIndex else { return FreeTier.dailyQuestionLimit }
        return max(0, FreeTier.dailyQuestionLimit - used)
    }

    public func canAsk(isPro: Bool, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let left = remaining(isPro: isPro, on: date, calendar: calendar) else { return true }
        return left > 0
    }

    /// Spends one question. Returns `false` (and changes nothing) if the free
    /// allowance is already exhausted.
    @discardableResult
    public mutating func consume(isPro: Bool, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let today = Self.dayIndex(for: date, calendar: calendar)
        rollIfNeeded(to: today)

        guard !isPro else {
            // Pro asks still increment so the counter is meaningful if a
            // subscription lapses mid-day.
            used += 1
            return true
        }
        guard used < FreeTier.dailyQuestionLimit else { return false }
        used += 1
        return true
    }

    /// Seconds until the free allowance refills, for the "come back at midnight" copy.
    public func secondsUntilReset(on date: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        let startOfTomorrow = calendar.startOfDay(for: date).addingTimeInterval(86_400)
        return max(0, startOfTomorrow.timeIntervalSince(date))
    }
}
