import Foundation

/// The app's disclaimer, in one place.
///
/// Kept in the core module rather than inline in a view so the first-run gate,
/// the Settings screen and the App Store listing all quote the same words. A
/// disclaimer that says three slightly different things in three places is
/// worth less than one that says the same thing everywhere.
public enum Disclaimer {

    public static let title = "Ask the Orb is a game"

    /// Shown on first launch, and any time the user opens it from Settings.
    public static let points: [(heading: String, body: String)] = [
        (
            "Every answer is random",
            "The orb draws from the odds you set. It knows nothing about you, your situation, or what happens next, and its answers carry no meaning beyond the roll that produced them."
        ),
        (
            "Nothing here is advice",
            "Not medical, legal, financial, psychological, or safety advice. Don't use it to decide anything that matters — for that, talk to someone qualified."
        ),
        (
            "It won't answer everything",
            "Questions about self-harm, violence, abuse, or medical care get support resources instead of a reading. That's on purpose, and it can't be switched off."
        ),
        (
            "In an emergency, don't use an app",
            "Contact your local emergency services — 911 in the US, 999 in the UK, 112 across the EU."
        )
    ]

    public static let acknowledgement =
        "By continuing you confirm you understand this app is entertainment, and that you won't rely on it for real decisions."

    /// One-paragraph version, for the store listing and Settings footer.
    public static let short =
        "Ask the Orb is entertainment only. Answers are drawn at random from odds you choose. The app cannot predict anything, and nothing it says is medical, legal, financial, or psychological advice."
}
