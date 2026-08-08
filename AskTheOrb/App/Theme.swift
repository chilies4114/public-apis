import SwiftUI
import OrbCore

enum Theme {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.12),
            Color(red: 0.10, green: 0.06, blue: 0.20),
            Color(red: 0.03, green: 0.03, blue: 0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.45, green: 0.55, blue: 1.0)

    static func tint(for sentiment: Sentiment) -> Color {
        switch sentiment {
        case .affirmative: return Color(red: 0.30, green: 0.80, blue: 0.55)
        case .noncommittal: return Color(red: 0.95, green: 0.75, blue: 0.30)
        case .negative: return Color(red: 0.95, green: 0.42, blue: 0.45)
        }
    }
}

/// The dark gradient backdrop shared by every screen.
struct CosmicBackground: View {
    var body: some View {
        Theme.background
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [Theme.accent.opacity(0.22), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Card styling used for every grouped block in the app.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }
}
