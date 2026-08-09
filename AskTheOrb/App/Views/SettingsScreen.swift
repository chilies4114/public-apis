import SwiftUI
import StoreKit
import OrbCore

@MainActor
struct SettingsScreen: View {
    @EnvironmentObject private var store: SubscriptionManager
    @EnvironmentObject private var preferences: Preferences

    @Environment(\.openURL) private var openURL

    @State private var paywallFeature: ProFeature?
    @State private var showManageSubscriptions = false
    @State private var showDisclaimer = false

    #if DEBUG
    @State private var passphrase = ""
    @State private var unlockFailed = false
    #endif

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
                        #if DEBUG
                        developerCard
                        #endif
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
            .sheet(isPresented: $showDisclaimer) {
                DisclaimerScreen(mode: .reference)
            }
        }
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isPro ? "Orb Pro" : "Free")
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

            Text(Disclaimer.short)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(.white.opacity(0.1))

            Button("Disclaimer") { showDisclaimer = true }
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

    // MARK: - Developer

    #if DEBUG
    /// Passphrase unlock for testing paid features without buying them.
    ///
    /// Debug-only by design: shipping a hidden unlock in a release build is an
    /// App Review 2.3.1 violation. This whole section does not exist in the
    /// App Store binary.
    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Developer").font(.headline)
                Spacer()
                Text("DEBUG BUILD")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.tint(for: .noncommittal).opacity(0.22)))
                    .foregroundStyle(Theme.tint(for: .noncommittal))
            }

            if store.ownerUnlocked {
                Label("Owner access on — every Pro feature unlocked", systemImage: "lock.open.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.tint(for: .affirmative))

                Button("Lock again") {
                    store.relockOwnerAccess()
                    passphrase = ""
                    unlockFailed = false
                }
                .font(.subheadline.weight(.medium))
            } else {
                Text("Unlock every pack, scale and Pro feature on this device without a purchase.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Passphrase", text: $passphrase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
                    .onSubmit(attemptUnlock)

                if unlockFailed {
                    Text("That passphrase doesn't match.")
                        .font(.caption)
                        .foregroundStyle(Theme.tint(for: .negative))
                }

                Button("Unlock", action: attemptUnlock)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                    .foregroundStyle(.white)
                    .disabled(passphrase.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func attemptUnlock() {
        let granted = store.unlockAsOwner(passphrase: passphrase)
        unlockFailed = !granted
        if granted { passphrase = "" }
        Feedback.blocked(enabled: !granted && preferences.hapticsEnabled)
    }
    #endif

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
