import Foundation

/// Product identifiers, mirrored in `Configuration/Products.storekit` and in
/// App Store Connect. These three strings must match in all three places or
/// purchases silently fail to resolve — see docs/DEPLOYMENT.md.
enum StoreConfig {
    static let monthlyID = "com.eightballoracle.pro.monthly"
    static let annualID = "com.eightballoracle.pro.annual"
    static let lifetimeID = "com.eightballoracle.pro.lifetime"

    /// Auto-renewing subscriptions, in the order the paywall lists them.
    static let subscriptionIDs = [annualID, monthlyID]

    /// Non-consumable one-time unlock.
    static let nonConsumableIDs = [lifetimeID]

    static var allProductIDs: [String] { subscriptionIDs + nonConsumableIDs }

    /// Apple's hosted terms/privacy URLs are required on any screen that sells a
    /// subscription (App Review guideline 3.1.2).
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://eightballoracle.app/privacy")!
    static let supportURL = URL(string: "https://eightballoracle.app/support")!
}
