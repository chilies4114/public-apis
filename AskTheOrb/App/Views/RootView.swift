import SwiftUI
import OrbCore

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore

    @State private var selection: Tab = .ask

    enum Tab: Hashable {
        case ask, odds, history, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            AskScreen()
                .tabItem { Label("Ask", systemImage: "moon.stars.fill") }
                .tag(Tab.ask)

            OddsScreen()
                .tabItem { Label("Odds", systemImage: "slider.horizontal.3") }
                .tag(Tab.odds)

            HistoryScreen()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .onAppear {
            history.applyRetention(isPro: store.isPro)
        }
        // Full screen cover, not a sheet: the disclaimer is a gate on first
        // launch and must not be swipeable.
        .fullScreenCover(isPresented: .constant(!preferences.hasSeenOnboarding)) {
            DisclaimerScreen(mode: .gate) {
                preferences.hasSeenOnboarding = true
            }
        }
        .alert(
            "App Store",
            isPresented: Binding(
                get: { store.alertMessage != nil },
                set: { if !$0 { store.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.alertMessage = nil }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }
}
