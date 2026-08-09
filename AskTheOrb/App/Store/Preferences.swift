import Foundation
import Combine
import OrbCore

/// User-facing settings plus the free-tier ask counter.
///
/// Everything lives in `UserDefaults`: it's all small, non-sensitive, and must
/// survive a relaunch. Entitlement deliberately does *not* live here — it is
/// always read from StoreKit so that a lapsed subscription can't be faked by
/// editing preferences.
///
/// Only ever touched from the main thread (SwiftUI views and the app's
/// entitlement callback), so it needs no synchronisation of its own.
final class Preferences: ObservableObject {

    private enum Key {
        static let enabledPacks = "packs.enabled"
        static let hapticsEnabled = "feedback.haptics"
        static let soundEnabled = "feedback.sound"
        static let allowance = "quota.allowance"
        static let hasSeenOnboarding = "onboarding.seen"
    }

    private let defaults: UserDefaults

    @Published var enabledPackIDs: Set<String> { didSet { defaults.set(Array(enabledPackIDs), forKey: Key.enabledPacks) } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    @Published var hasSeenOnboarding: Bool { didSet { defaults.set(hasSeenOnboarding, forKey: Key.hasSeenOnboarding) } }
    @Published private(set) var allowance: AskAllowance { didSet { persistAllowance() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.hapticsEnabled = defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true
        self.soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        self.hasSeenOnboarding = defaults.bool(forKey: Key.hasSeenOnboarding)

        if let stored = defaults.array(forKey: Key.enabledPacks) as? [String], !stored.isEmpty {
            // Drop packs that no longer ship, so a removed pack can't strand the user.
            let known = Set(stored).intersection(AnswerCatalog.allPackIDs)
            self.enabledPackIDs = known.isEmpty ? FreeTier.packIDs : known
        } else {
            self.enabledPackIDs = FreeTier.packIDs
        }

        if let data = defaults.data(forKey: Key.allowance),
           let decoded = try? JSONDecoder().decode(AskAllowance.self, from: data) {
            self.allowance = decoded
        } else {
            self.allowance = AskAllowance()
        }
    }

    // MARK: - Derived pool

    /// Packs the orb may draw from, after entitlement is applied.
    func activePackIDs(isPro: Bool) -> Set<String> {
        guard isPro else { return FreeTier.packIDs }
        let allowed = enabledPackIDs.intersection(AnswerCatalog.allPackIDs)
        return allowed.isEmpty ? FreeTier.packIDs : allowed
    }

    /// The odds the orb is actually running — counted, not configured.
    func measuredOdds(isPro: Bool) -> OddsMeasurement {
        OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: activePackIDs(isPro: isPro))
    }

    // MARK: - Quota

    func remainingAsks(isPro: Bool, now: Date = Date()) -> Int? {
        allowance.remaining(isPro: isPro, on: now)
    }

    func canAsk(isPro: Bool, now: Date = Date()) -> Bool {
        allowance.canAsk(isPro: isPro, on: now)
    }

    @discardableResult
    func consumeAsk(isPro: Bool, now: Date = Date()) -> Bool {
        var copy = allowance
        let granted = copy.consume(isPro: isPro, on: now)
        allowance = copy
        return granted
    }

    // MARK: - Entitlement changes

    /// Called whenever Pro is gained or lost.
    ///
    /// Losing Pro must visibly reset the user to free behaviour instead of
    /// leaving stale Pro selections on screen.
    func reconcileWithEntitlement(isPro: Bool) {
        guard !isPro else { return }
        enabledPackIDs = FreeTier.packIDs
    }

    // MARK: - Persistence

    private func persistAllowance() {
        guard let data = try? JSONEncoder().encode(allowance) else { return }
        defaults.set(data, forKey: Key.allowance)
    }
}
