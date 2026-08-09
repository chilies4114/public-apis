import Foundation
import StoreKit

/// Owns everything StoreKit: product metadata, the entitlement set, purchases
/// and restores.
///
/// Entitlement is derived from `Transaction.currentEntitlements` and never
/// cached to disk. That means a cancelled subscription loses Pro on the next
/// refresh, and a user who reinstalls gets Pro back without a "restore" tap —
/// both of which App Review checks for.
@MainActor
final class SubscriptionManager: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var entitledProductIDs: Set<String> = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var alertMessage: String?

    /// True when the App Store says a Pro product is currently entitled.
    var isEntitled: Bool { !entitledProductIDs.isEmpty }

    /// What the app gates features on.
    ///
    /// In Release this is exactly `isEntitled`. In Debug it also honours the
    /// developer's passphrase unlock, which is compiled out of shipping builds
    /// entirely — see OwnerUnlock.swift.
    var isPro: Bool {
        #if DEBUG
        return isEntitled || ownerUnlocked
        #else
        return isEntitled
        #endif
    }

    var hasLifetime: Bool { entitledProductIDs.contains(StoreConfig.lifetimeID) }

    #if DEBUG
    /// Published so that unlocking re-renders every gated view immediately.
    @Published private(set) var ownerUnlocked: Bool = OwnerUnlock.isUnlocked

    @discardableResult
    func unlockAsOwner(passphrase: String) -> Bool {
        guard OwnerUnlock.unlock(with: passphrase) else { return false }
        ownerUnlocked = true
        return true
    }

    func relockOwnerAccess() {
        OwnerUnlock.relock()
        ownerUnlocked = false
    }
    #endif

    /// Retained for the lifetime of the app; the listener must outlive any one
    /// screen so purchases made outside the app (Ask to Buy approvals, family
    /// sharing, redeemed codes) still land.
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
    }

    // MARK: - Lifecycle

    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: StoreConfig.allProductIDs)

            // Preserve the paywall's intended order rather than StoreKit's.
            subscriptions = StoreConfig.subscriptionIDs.compactMap { id in
                products.first { $0.id == id }
            }
            lifetimeProduct = products.first { $0.id == StoreConfig.lifetimeID }

            if products.isEmpty {
                loadState = .failed("Couldn't reach the App Store. Pull to try again.")
            } else {
                loadState = .loaded
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Purchasing

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true

            case .userCancelled:
                return false

            case .pending:
                // Ask to Buy / SCA. The transaction listener will pick it up.
                alertMessage = "Your purchase is pending approval. Pro unlocks as soon as it's approved."
                return false

            @unknown default:
                return false
            }
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
        } catch {
            // A failed sync is not fatal — currentEntitlements may still resolve
            // from the on-device receipt, so refresh before reporting anything.
            await refreshEntitlements()
            alertMessage = isPro ? nil : error.localizedDescription
            return
        }

        await refreshEntitlements()
        alertMessage = isPro ? "Pro restored." : "No previous purchases found on this Apple Account."
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var active: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            active.insert(transaction.productID)
        }

        entitledProductIDs = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? Self.verify(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    // MARK: - Presentation helpers

    /// Introductory offer on a subscription, if the user is eligible for it.
    func introductoryOffer(for product: Product) async -> Product.SubscriptionOffer? {
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer else { return nil }
        guard await subscription.isEligibleForIntroOffer else { return nil }
        return offer
    }

    /// "7 days free, then $14.99/year"-style copy, or plain price if no offer.
    func offerCaption(for product: Product, offer: Product.SubscriptionOffer?) -> String {
        guard let offer else { return "\(product.displayPrice)\(periodSuffix(for: product))" }

        let unitCount = offer.period.value
        let unit = Self.unitName(offer.period.unit, count: unitCount)
        let lead = offer.paymentMode == .freeTrial
            ? "\(unitCount) \(unit) free"
            : "\(offer.displayPrice) for \(unitCount) \(unit)"
        return "\(lead), then \(product.displayPrice)\(periodSuffix(for: product))"
    }

    func periodSuffix(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let unit = Self.unitName(period.unit, count: period.value)
        return period.value == 1 ? "/\(unit)" : " / \(period.value) \(unit)"
    }

    /// Percentage saved by the annual plan versus paying monthly, or nil when
    /// both products aren't loaded or the maths isn't favourable.
    var annualSavingsPercent: Int? {
        guard let annual = subscriptions.first(where: { $0.id == StoreConfig.annualID }),
              let monthly = subscriptions.first(where: { $0.id == StoreConfig.monthlyID })
        else { return nil }

        let yearOfMonthly = monthly.price * Decimal(12)
        guard yearOfMonthly > 0, annual.price < yearOfMonthly else { return nil }
        let saved = (yearOfMonthly - annual.price) / yearOfMonthly * 100
        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    private static func unitName(_ unit: Product.SubscriptionPeriod.Unit, count: Int) -> String {
        let singular: String
        switch unit {
        case .day: singular = "day"
        case .week: singular = "week"
        case .month: singular = "month"
        case .year: singular = "year"
        @unknown default: singular = "period"
        }
        return count == 1 ? singular : singular + "s"
    }

    // MARK: - Verification

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            "This purchase couldn't be verified with the App Store."
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        try Self.verify(result)
    }

    private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
