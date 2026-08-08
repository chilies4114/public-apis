import SwiftUI
import StoreKit
import EightBallCore

@MainActor
struct SettingsScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences

    @Environment(\.openURL) private var openURL

    @State private var paywallFeature: ProFeature?
    @State private var showManageSubscriptions = false

    private var isPro: Bool { store.isPro }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        subscriptionCard
                        feedbackCard
                        aboutCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $paywallFeature) { feature in
                PaywallView(highlight: feature).environmentObject(store)
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        }
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isPro ? "Eight Ball Pro" : "Free")
                    .font(.headline)
                Spacer()
                if isPro {
                    Label(store.hasLifetime ? "Lifetime" : "Active", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.tint(for: .affirmative))
                }
            }

            if isPro {
                Text("Thanks for supporting the app. Every pack, every scale, unlimited questions.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))

                if !store.hasLifetime {
                    Button("Manage subscription") { showManageSubscriptions = true }
                        .font(.subheadline.weight(.medium))
                }
            } else {
                Text("You're on the free plan: \(FreeTier.dailyQuestionLimit) questions a day, the Classic pack, and the classic odds.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    paywallFeature = .unlimitedAsks
                } label: {
                    Text("See Pro")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
                .foregroundStyle(.white)
            }

            Button {
                Task { await store.restorePurchases() }
            } label: {
                if store.isRestoring {
                    ProgressView()
                } else {
                    Text("Restore purchases").font(.subheadline)
                }
            }
            .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Feedback

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Haptics", isOn: Binding(
                get: { preferences.hapticsEnabled },
                set: { preferences.hapticsEnabled = $0 }
            ))
            Divider().overlay(.white.opacity(0.1))
            Toggle("Sound", isOn: Binding(
                get: { preferences.soundEnabled },
                set: { preferences.soundEnabled = $0 }
            ))
        }
        .tint(Theme.accent)
        .cardStyle()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            Text("Eight Ball Oracle is a toy. Answers are drawn at random from the odds you choose — it can't actually see the future, and nothing it says should be used for medical, legal, or financial decisions.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(.white.opacity(0.1))

            Button("Support") { openURL(StoreConfig.supportURL) }
            Button("Privacy Policy") { openURL(StoreConfig.privacyURL) }
            Button("Terms of Use") { openURL(StoreConfig.termsURL) }

            Text(versionString)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
