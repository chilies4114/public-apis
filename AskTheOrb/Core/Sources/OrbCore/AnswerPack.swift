import Foundation

/// A single line the orb can surface.
public struct Answer: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let text: String
    public let sentiment: Sentiment
    public let packID: String

    public init(id: String, text: String, sentiment: Sentiment, packID: String) {
        self.id = id
        self.text = text
        self.sentiment = sentiment
        self.packID = packID
    }
}

/// A themed collection of answers.
///
/// Packs never change the odds — the probability scale decides the verdict, the
/// pack only decides the wording. That separation is what keeps a Pro pack from
/// quietly being "luckier" than the free one.
public struct AnswerPack: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    public let symbolName: String
    public let requiresPro: Bool
    public let answers: [Answer]

    public init(id: String, name: String, tagline: String, symbolName: String, requiresPro: Bool, answers: [Answer]) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.symbolName = symbolName
        self.requiresPro = requiresPro
        self.answers = answers
    }

    public func answers(for sentiment: Sentiment) -> [Answer] {
        answers.filter { $0.sentiment == sentiment }
    }

    /// True when the pack can serve every verdict the scale might produce.
    public var isComplete: Bool {
        Sentiment.allCases.allSatisfy { !answers(for: $0).isEmpty }
    }
}

private func makeAnswers(
    packID: String,
    affirmative: [String],
    noncommittal: [String],
    negative: [String]
) -> [Answer] {
    var result: [Answer] = []
    let groups: [(Sentiment, [String])] = [
        (.affirmative, affirmative),
        (.noncommittal, noncommittal),
        (.negative, negative)
    ]
    for (sentiment, lines) in groups {
        for (index, line) in lines.enumerated() {
            result.append(
                Answer(
                    id: "\(packID).\(sentiment.rawValue).\(index)",
                    text: line,
                    sentiment: sentiment,
                    packID: packID
                )
            )
        }
    }
    return result
}

public enum AnswerCatalog {
    public static let classicPackID = "classic"

    /// The 20 canonical answers, free forever.
    public static let classic = AnswerPack(
        id: classicPackID,
        name: "Classic",
        tagline: "The twenty answers everyone knows.",
        symbolName: "quote.bubble.fill",
        requiresPro: false,
        answers: makeAnswers(
            packID: classicPackID,
            affirmative: [
                "It is certain.",
                "It is decidedly so.",
                "Without a doubt.",
                "Yes — definitely.",
                "You may rely on it.",
                "As I see it, yes.",
                "Most likely.",
                "Outlook good.",
                "Yes.",
                "Signs point to yes."
            ],
            noncommittal: [
                "Reply hazy, try again.",
                "Ask again later.",
                "Better not tell you now.",
                "Cannot predict now.",
                "Concentrate and ask again."
            ],
            negative: [
                "Don't count on it.",
                "My reply is no.",
                "My sources say no.",
                "Outlook not so good.",
                "Very doubtful."
            ]
        )
    )

    static let cosmic = AnswerPack(
        id: "cosmic",
        name: "Cosmic",
        tagline: "Answers from somewhere considerably further out.",
        symbolName: "sparkles",
        requiresPro: true,
        answers: makeAnswers(
            packID: "cosmic",
            affirmative: [
                "The stars have already signed off on this.",
                "Every orbit says go.",
                "The universe is holding the door for you.",
                "Written in light. Yes.",
                "Gravity itself is on your side.",
                "This one was always going to happen.",
                "The constellations are unanimous.",
                "Yes — and sooner than you think."
            ],
            noncommittal: [
                "The signal is still crossing the void.",
                "Ask when the moon has moved.",
                "Two futures are still arguing about this.",
                "The answer exists. It has not arrived.",
                "Cosmic static. Try again."
            ],
            negative: [
                "The heavens decline.",
                "This timeline closes here.",
                "The void says no, and the void is rarely wrong.",
                "Not in this orbit.",
                "The stars looked away."
            ]
        )
    )

    static let deadpan = AnswerPack(
        id: "deadpan",
        name: "Deadpan",
        tagline: "Honest to a fault. Possibly rude.",
        symbolName: "face.smiling.inverse",
        requiresPro: true,
        answers: makeAnswers(
            packID: "deadpan",
            affirmative: [
                "Yes. Obviously. Next question.",
                "Sure, why not. You've earned one.",
                "Yes, and you already knew that.",
                "Fine. Yes. Go on then.",
                "Statistically? Yes. Emotionally? Also yes.",
                "Yes, but don't make it weird.",
                "Correct, for once.",
                "Yes. Try not to squander it."
            ],
            noncommittal: [
                "I'm going to need more context, and so do you.",
                "That's a you problem. Ask again later.",
                "Bold of you to ask a plastic sphere.",
                "Unclear, and frankly none of my business.",
                "Come back when you actually want the answer."
            ],
            negative: [
                "No. Sorry. Well — not that sorry.",
                "Absolutely not.",
                "That's a no, and you knew it before you asked.",
                "Hard no. Take the afternoon off.",
                "No, but it was fun watching you hope."
            ]
        )
    )

    static let fortune = AnswerPack(
        id: "fortune",
        name: "Fortune Cookie",
        tagline: "Vaguely wise. Suspiciously comforting.",
        symbolName: "leaf.fill",
        requiresPro: true,
        answers: makeAnswers(
            packID: "fortune",
            affirmative: [
                "The path you fear is the one already cleared for you.",
                "What you are waiting for is also waiting for you.",
                "Yes. Begin before you feel ready.",
                "The door was never locked.",
                "Fortune favours the one who asked.",
                "Say yes, and the rest will arrange itself.",
                "You will look back on this kindly.",
                "The answer is yes, and it is patient."
            ],
            noncommittal: [
                "A question asked too early answers itself too late.",
                "Stillness now. Clarity soon.",
                "The river has not chosen its bank.",
                "What is hidden is not yet ripe.",
                "Wait one turn of the moon."
            ],
            negative: [
                "Not this. Something better is queued behind it.",
                "The road ends here so another can begin.",
                "Let this one go gently.",
                "No — and that is a mercy.",
                "What you want is not what you need."
            ]
        )
    )

    static let boardroom = AnswerPack(
        id: "boardroom",
        name: "Boardroom",
        tagline: "For decisions that need a paper trail.",
        symbolName: "chart.line.uptrend.xyaxis",
        requiresPro: true,
        answers: makeAnswers(
            packID: "boardroom",
            affirmative: [
                "Approved. Ship it.",
                "Green light. Proceed to next milestone.",
                "The data supports moving forward.",
                "Signed off, pending nothing.",
                "Yes — strong upside, acceptable risk.",
                "Consensus reached. It's a go.",
                "This clears the bar comfortably.",
                "Recommend proceeding at pace."
            ],
            noncommittal: [
                "Tabled pending further review.",
                "Insufficient data. Circle back Q3.",
                "Let's take that one offline.",
                "Parking this in the backlog for now.",
                "Needs another round of discovery."
            ],
            negative: [
                "Declined. The numbers don't support it.",
                "Not this quarter. Not next either.",
                "Risk register says no.",
                "Blocked. Escalate if you disagree.",
                "Recommend we walk away from this one."
            ]
        )
    )

    static let highSeas = AnswerPack(
        id: "highseas",
        name: "High Seas",
        tagline: "Salt-crusted prophecy, barnacles included.",
        symbolName: "sailboat.fill",
        requiresPro: true,
        answers: makeAnswers(
            packID: "highseas",
            affirmative: [
                "Aye, and the wind's behind ye.",
                "Chart the course. The sea agrees.",
                "That treasure has your name carved in it.",
                "Aye — full sail, no hesitation.",
                "The tide turns for ye today.",
                "Every gull says go.",
                "Aye. Weigh anchor.",
                "The compass has made up its mind."
            ],
            noncommittal: [
                "Fog on the water. Ask at first light.",
                "The charts here are blank, matey.",
                "Becalmed. No answer without wind.",
                "Even the sea don't know yet.",
                "Ask again when the gulls come back."
            ],
            negative: [
                "Nay. That course runs to rocks.",
                "The kraken says otherwise.",
                "Not while there's breath in this crew.",
                "Nay — turn about while ye can.",
                "That ship sailed, and it sank."
            ]
        )
    )

    /// Every pack the app ships with, free pack first.
    public static let all: [AnswerPack] = [classic, cosmic, deadpan, fortune, boardroom, highSeas]

    public static let freePackIDs: Set<String> = Set(all.filter { !$0.requiresPro }.map(\.id))
    public static let allPackIDs: Set<String> = Set(all.map(\.id))

    public static func pack(withID id: String) -> AnswerPack? {
        all.first { $0.id == id }
    }

    /// Pack IDs a user may draw from, given what they've paid for.
    public static func availablePackIDs(isPro: Bool) -> Set<String> {
        isPro ? allPackIDs : freePackIDs
    }
}
