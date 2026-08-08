import Foundation

/// Launch flags used by the UI test target.
///
/// Kept behind explicit argument checks (never a build flag) so the shipping
/// binary behaves identically — the flags simply are never passed.
enum LaunchArguments {
    static let resetState = "-AskTheOrbResetState"

    static var shouldResetState: Bool {
        ProcessInfo.processInfo.arguments.contains(resetState)
    }

    /// Wipes preferences and history so each UI test starts from a known state.
    static func resetIfRequested() {
        guard shouldResetState else { return }

        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("history.json")
        if let support {
            try? FileManager.default.removeItem(at: support)
        }
    }
}

/// Accessibility identifiers shared between the app and the UI tests, so a
/// renamed button breaks the build rather than the test suite.
enum A11y {
    static let questionField = "ask.questionField"
    static let askButton = "ask.askButton"
    static let askAgainButton = "ask.askAgainButton"
    static let orb = "ask.orb"
    static let readingCard = "ask.readingCard"
    static let readingVerdict = "ask.readingVerdict"
    static let quotaLabel = "ask.quotaLabel"
    static let goProButton = "ask.goProButton"
    static let paywall = "paywall.root"
}
