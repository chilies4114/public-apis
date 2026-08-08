import SwiftUI
import StoreKit
import EightBallCore

/// The subscription screen.
///
/// Deliberately states price, period, renewal behaviour and links to Terms and
/// Privacy on the same screen as the buy button — App Review guideline 3.1.2
/// rejects paywalls that omit any of those.
@MainActor
struct PaywallView: View {
    /// The feature that sent the user here, so the copy answers the question
    /// they were actually asking.
    let highlight: ProFeature

    @EnvironmentObject private var store: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String = StoreConfig.annualID
    @State private var introOffers: [String: Product.SubscriptionOffer] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        featureList
                        planPicker
                        buyButton
                        legalFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .accessibilityIdentifier(A11y.paywall)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") {
                        Task { await store.restorePurchases() }
                    }
                    .disabled(store.isRestoring)
                }
            }
            .task { await loadOffers() }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: highlight.symbolName)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 12)

            Text(highlight.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text(highlight.detail)
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Everything in Pro")
                .font(.headline)

            ForEach(ProFeature.allCases) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.symbolName)
                        .frame(width: 24)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.weight(.semibold))
                        Text(feature.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var planPicker: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView("Loading plans…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await store.loadProducts() } }
                    .buttonStyle(.bordered)
            }
            .cardStyle()

        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.subscriptions, id: \.id) { product in
                    planRow(for: product)
                }
                if let lifetime = store.lifetimeProduct {
                    planRow(for: lifetime)
                }
            }
        }
    }

    private func planRow(for product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isLifetime = product.id == StoreConfig.lifetimeID

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : .white.opacity(0.4))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planTitle(for: product))
                            .font(.subheadline.weight(.semibold))
                        if product.id == StoreConfig.annualID, let saving = store.annualSavingsPercent {
                            Text("SAVE \(saving)%")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.tint(for: .affirmative).opacity(0.25)))
                                .foregroundStyle(Theme.tint(for: .affirmative))
                        }
                    }
                    Text(caption(for: product, isLifetime: isLifetime))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.13 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var buyButton: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(buyButtonTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
            .foregroundStyle(.white)
            .disabled(store.isPurchasing || selectedProduct == nil)

            Text(renewalDisclosure)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 18) {
            Link("Terms of Use", destination: StoreConfig.termsURL)
            Link("Privacy Policy", destination: StoreConfig.privacyURL)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.6))
    }

    // MARK: - Copy

    private var selectedProduct: Product? {
        store.subscriptions.first { $0.id == selectedProductID }
            ?? (selectedProductID == StoreConfig.lifetimeID ? store.lifetimeProduct : nil)
    }

    private func planTitle(for product: Product) -> String {
        switch product.id {
        case StoreConfig.annualID: return "Yearly"
        case StoreConfig.monthlyID: return "Monthly"
        case StoreConfig.lifetimeID: return "Lifetime"
        default: return product.displayName
        }
    }

    private func caption(for product: Product, isLifetime: Bool) -> String {
        if isLifetime { return "One payment. Yours forever." }
        return store.offerCaption(for: product, offer: introOffers[product.id])
    }

    private var buyButtonTitle: String {
        guard let product = selectedProduct else { return "Unavailable" }
        if product.id == StoreConfig.lifetimeID { return "Unlock Pro Forever" }
        if let offer = introOffers[product.id], offer.paymentMode == .freeTrial {
            return "Start Free Trial"
        }
        return "Continue"
    }

    private var renewalDisclosure: String {
        guard let product = selectedProduct, product.id != StoreConfig.lifetimeID else {
            return "One-time purchase. No subscription, no renewal."
        }
        let period = store.periodSuffix(for: product).replacingOccurrences(of: "/", with: "")
        return """
        Payment is charged to your Apple Account at confirmation. \
        The subscription renews automatically each \(period) at \(product.displayPrice) \
        unless cancelled at least 24 hours before the end of the current period. \
        Manage or cancel in Settings › Apple Account › Subscriptions.
        """
    }

    // MARK: - Actions

    private func loadOffers() async {
        if store.loadState != .loaded {
            await store.loadProducts()
        }
        var offers: [String: Product.SubscriptionOffer] = [:]
        for product in store.subscriptions {
            if let offer = await store.introductoryOffer(for: product) {
                offers[product.id] = offer
            }
        }
        introOffers = offers

        // Default to the plan with a trial if there is one, otherwise yearly.
        if let trialProduct = store.subscriptions.first(where: { offers[$0.id]?.paymentMode == .freeTrial }) {
            selectedProductID = trialProduct.id
        }
    }

    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        let success = await store.purchase(product)
        if success { dismiss() }
    }
}
