#if DEBUG

import Foundation
import CryptoKit

/// A passphrase-gated switch that grants Pro without a purchase, for the
/// developer's own device.
///
/// The entire file is inside `#if DEBUG`, which is not a detail — it is the
/// point. App Review guideline 2.3.1 prohibits hidden or undocumented
/// features, and a shipped build containing a secret unlock is a rejection
/// waiting to happen even if a reviewer never finds it. Compiling this out of
/// Release means the App Store binary has no backdoor to find.
///
/// Because it can never reach a shipping build, the passphrase hash below is
/// not a secret worth protecting and its presence in the repository costs
/// nothing. See docs/DEPLOYMENT.md for the sanctioned ways to get Pro for free
/// on a *release* build — TestFlight and subscription offer codes.
enum OwnerUnlock {

    /// SHA-256 of the passphrase. Default is `orb-owner`.
    ///
    /// To change it:
    ///
    ///     echo -n 'your new passphrase' | shasum -a 256
    ///
    /// and paste the hex here.
    private static let passphraseHash =
        "f4a6959261d4e9d632749e62baeb9c3ece9f4579c1716f262da84ff81b17162d"

    private static let defaultsKey = "developer.ownerUnlocked"

    static var isUnlocked: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    /// Checks the passphrase and, on a match, persists the unlock.
    @discardableResult
    static func unlock(with passphrase: String) -> Bool {
        guard matches(passphrase) else { return false }
        UserDefaults.standard.set(true, forKey: defaultsKey)
        return true
    }

    static func relock() {
        UserDefaults.standard.set(false, forKey: defaultsKey)
    }

    private static func matches(_ passphrase: String) -> Bool {
        let trimmed = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let digest = SHA256.hash(data: Data(trimmed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()

        // Constant-time-ish comparison. Overkill for a debug switch, but the
        // habit is worth keeping in code others may copy.
        guard hex.utf8.count == passphraseHash.utf8.count else { return false }
        var difference: UInt8 = 0
        for (lhs, rhs) in zip(hex.utf8, passphraseHash.utf8) {
            difference |= lhs ^ rhs
        }
        return difference == 0
    }
}

#endif
