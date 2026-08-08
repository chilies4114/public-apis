import SwiftUI
import AudioToolbox
import EightBallCore

#if canImport(UIKit)
import UIKit
#endif

/// Haptics and sound for the shake/reveal sequence.
///
/// Uses system sounds rather than bundled audio so the app ships without media
/// assets and never fights the user's ringer or another app's audio session.
@MainActor
enum Feedback {

    static func shakeStarted(enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
        #endif
    }

    static func tumble(enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        #endif
    }

    static func revealed(_ sentiment: Sentiment, haptics: Bool, sound: Bool) {
        #if canImport(UIKit)
        if haptics {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            switch sentiment {
            case .affirmative: generator.notificationOccurred(.success)
            case .noncommittal: generator.notificationOccurred(.warning)
            case .negative: generator.notificationOccurred(.error)
            }
        }
        #endif

        if sound {
            // 1104 is the short, quiet system "tock".
            AudioServicesPlaySystemSound(1104)
        }
    }

    static func blocked(enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func selection(enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
