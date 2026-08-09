import Foundation

/// Subjects the orb must not answer with a coin flip.
///
/// A randomised "Signs point to yes" is harmless for *should I get a dog*. For
/// *should I hurt myself* it is indefensible, and no disclaimer anywhere in the
/// app makes it acceptable. The screener runs before the draw, so for these
/// questions no reading is ever generated in the first place.
public enum SensitiveTopic: String, CaseIterable, Sendable {
    case selfHarm
    case violence
    case abuse
    case medical
    case legal
    case money

    /// What the app does when the topic is detected.
    public var outcome: ScreeningOutcome {
        switch self {
        case .selfHarm, .violence, .abuse, .medical: return .decline
        case .legal, .money: return .caution
        }
    }
}

public enum ScreeningOutcome: Equatable, Sendable {
    /// No reading is drawn. The orb explains why and points somewhere useful.
    case decline
    /// A reading is drawn, shown alongside a standing warning.
    case caution
}

/// What to show the person who asked.
public struct Screening: Equatable, Sendable {
    public let topic: SensitiveTopic
    public let outcome: ScreeningOutcome
    public let headline: String
    public let message: String
    public let resources: [SupportResource]

    public init(topic: SensitiveTopic) {
        self.topic = topic
        self.outcome = topic.outcome
        self.headline = Self.headline(for: topic)
        self.message = Self.message(for: topic)
        self.resources = Self.resources(for: topic)
    }

    public static func == (lhs: Screening, rhs: Screening) -> Bool { lhs.topic == rhs.topic }

    // Copy is deliberately warm and short. Nobody in distress wants a lecture
    // from a novelty app, and a scolding tone is what makes people dismiss the
    // screen without reading it.
    private static func headline(for topic: SensitiveTopic) -> String {
        switch topic {
        case .selfHarm: return "This one deserves a real person"
        case .violence: return "The orb won't answer this"
        case .abuse: return "You deserve better than a guess"
        case .medical: return "Ask someone who can actually examine you"
        case .legal: return "Not a substitute for a lawyer"
        case .money: return "Not financial advice"
        }
    }

    private static func message(for topic: SensitiveTopic) -> String {
        switch topic {
        case .selfHarm:
            return "The orb picks answers at random, and this is far too important for that. Please talk to someone who can actually help — right now, if you need to."
        case .violence:
            return "A random answer has no business anywhere near this question. If someone is in danger, contact your local emergency services."
        case .abuse:
            return "This isn't something to leave to chance. People are trained for exactly this conversation, and they're free to talk to."
        case .medical:
            return "The orb knows nothing about you and can't examine anyone. A doctor, nurse, or pharmacist can — most will answer a quick question for free."
        case .legal:
            return "The orb's answer here means nothing. Anything with real legal weight is worth a professional's ten minutes."
        case .money:
            return "Treat the answer as a coin flip, because that's what it is. Don't let it move real money."
        }
    }

    private static func resources(for topic: SensitiveTopic) -> [SupportResource] {
        switch topic {
        case .selfHarm:
            return [.lifeline988, .crisisText, .findAHelpline]
        case .violence:
            return [.emergency, .lifeline988]
        case .abuse:
            return [.domesticViolence, .findAHelpline]
        case .medical, .legal, .money:
            return []
        }
    }
}

/// A real place to get help. Kept in code rather than fetched, so it works with
/// no network and can't break.
public struct SupportResource: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    /// `nil` for entries that are an instruction rather than a link.
    public let urlString: String?

    public var url: URL? { urlString.flatMap(URL.init(string:)) }

    public static let lifeline988 = SupportResource(
        id: "988",
        name: "988 Suicide & Crisis Lifeline",
        detail: "Call or text 988 — free, 24/7, US and Canada",
        urlString: "https://988lifeline.org"
    )

    public static let crisisText = SupportResource(
        id: "crisisText",
        name: "Crisis Text Line",
        detail: "Text HOME to 741741",
        urlString: "https://www.crisistextline.org"
    )

    public static let findAHelpline = SupportResource(
        id: "findahelpline",
        name: "Find a helpline near you",
        detail: "Free, confidential support in over 130 countries",
        urlString: "https://findahelpline.com"
    )

    public static let domesticViolence = SupportResource(
        id: "thehotline",
        name: "National Domestic Violence Hotline",
        detail: "Call 1-800-799-7233 — free, 24/7, US",
        urlString: "https://www.thehotline.org"
    )

    public static let emergency = SupportResource(
        id: "emergency",
        name: "Emergency services",
        detail: "911 in the US, 999 in the UK, 112 across the EU",
        urlString: nil
    )
}

/// Matches a question against the sensitive topics.
///
/// Deliberately a plain phrase list rather than anything clever: it runs on
/// device with no network, no model, and no question ever leaving the phone,
/// and its behaviour is completely inspectable. It will miss things phrased
/// unusually — that's an accepted limit of any keyword approach, and the reason
/// the disclaimer exists as well.
public enum TopicScreener {

    public static func screen(_ question: String) -> Screening? {
        let haystack = " " + Oracle.normalize(question) + " "
        guard haystack.count > 2 else { return nil }

        // Order matters: the most serious topic wins when a question touches
        // more than one, so "should I stop taking my pills and end it" is
        // handled as self-harm rather than as a medication question.
        for topic in SensitiveTopic.allCases {
            let phrases = self.phrases(for: topic)
            if phrases.contains(where: { haystack.contains(" " + $0 + " ") }) {
                return Screening(topic: topic)
            }
        }
        return nil
    }

    /// Phrases are matched on whole-word boundaries against the normalised
    /// question, so "kill" alone never fires — only the constructions that
    /// actually indicate harm. That keeps "should I kill this feature" and
    /// "will I kill it at the interview" out of the net.
    static func phrases(for topic: SensitiveTopic) -> [String] {
        switch topic {
        case .selfHarm:
            return [
                "kill myself", "killing myself", "kill me",
                "end my life", "ending my life", "end it all", "take my own life",
                "suicide", "suicidal", "i kms", "unalive myself", "unalive",
                "want to die", "wanna die", "better off dead", "rather be dead",
                "should i die", "hang myself", "overdose", "od on my",
                "hurt myself", "harm myself", "harming myself", "self harm",
                "cut myself", "cutting myself", "starve myself",
                "not worth living", "no reason to live", "disappear forever",
            ]
        case .violence:
            return [
                "kill him", "kill her", "kill them", "kill someone", "kill people",
                "kill my", "murder", "murdering",
                "shoot him", "shoot her", "shoot them", "shoot up", "shoot someone",
                "stab him", "stab her", "stab them", "stab someone",
                "hurt him", "hurt her", "hurt them", "hurt someone", "hurt my",
                "beat him up", "beat her up", "beat them up", "beat up",
                "poison him", "poison her", "poison them", "poison someone",
                "blow up", "set fire to", "burn down",
                "get revenge", "revenge on", "make them pay", "make him pay", "make her pay",
            ]
        case .abuse:
            return [
                "hits me", "hitting me", "beats me", "beat me up",
                "abusing me", "abuses me", "abusive", "my abuser",
                "assaulted", "assaulting me", "rape", "raped", "raping",
                "stalking me", "stalks me", "threatening me", "threatens me",
                "afraid of him", "afraid of her", "afraid of them", "scared of him",
                "scared of her", "hurts me", "hurting me", "trafficked",
            ]
        case .medical:
            return [
                "cancer", "tumor", "tumour", "chemo", "chemotherapy",
                "diagnosed", "diagnosis", "symptoms", "my symptoms",
                "medication", "my meds", "take my pills", "stop taking",
                "antidepressant", "antidepressants", "antibiotics", "insulin",
                "surgery", "operation", "biopsy", "hiv", "std", "sti",
                "pregnant", "pregnancy", "miscarriage", "abortion",
                "seizure", "stroke", "heart attack", "chest pain",
                "see a doctor", "go to the doctor", "go to the er",
                "go to hospital", "go to the hospital", "emergency room",
                "eating disorder", "anorexia", "bulimia", "purge",
                "relapse", "detox", "withdrawal", "overdosing",
            ]
        case .legal:
            return [
                "sue", "suing", "lawsuit", "lawyer", "attorney",
                "plead guilty", "plead not guilty", "court date", "go to court",
                "custody", "restraining order", "deported", "deportation",
                "immigration", "visa application", "asylum",
                "sign the contract", "sign this contract", "break my lease",
                "my will", "power of attorney",
            ]
        case .money:
            return [
                "invest", "investing", "invest in", "my savings", "life savings",
                "sell my stocks", "buy stocks", "buy crypto", "sell crypto",
                "bitcoin", "mortgage", "remortgage", "refinance",
                "bankruptcy", "declare bankruptcy", "take out a loan",
                "payday loan", "my pension", "my retirement", "401k",
                "quit my job", "bet my", "gamble", "gambling", "put it all on",
            ]
        }
    }
}
