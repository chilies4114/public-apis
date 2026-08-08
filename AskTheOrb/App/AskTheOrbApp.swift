import SwiftUI
import OrbCore

@main
@MainActor
struct AskTheOrbApp: App {
    @StateObject private var store = SubscriptionManager()
    @StateObject private var preferences: Preferences
    @StateObject private var history: HistoryStore

    init() {
        // Must run before the stores read anything off disk.
        LaunchArguments.resetIfRequested()
        _preferences = StateObject(wrappedValue: Preferences())
        _history = StateObject(wrappedValue: HistoryStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(preferences)
                .environmentObject(history)
                .task {
                    // Products and entitlements are both needed before the first
                    // paywall or gate can render honestly, so load them together
                    // at launch rather than lazily at the point of use.
                    await store.start()
                }
                .onChange(of: store.isPro) { _, isPro in
                    preferences.reconcileWithEntitlement(isPro: isPro)
                    history.applyRetention(isPro: isPro)
                }
        }
    }
}
