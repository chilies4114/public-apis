import XCTest
@testable import OrbCore

final class OracleTests: XCTestCase {

    private let oracle = Oracle()
    private let allPacks = AnswerCatalog.allPackIDs
    private let freePacks = AnswerCatalog.freePackIDs

    // MARK: - The odds actually match the scale

    /// The whole product promise is that the scale controls the outcome, so this
    /// is the test that matters most: draw a lot, count the verdicts, compare.
    func testDrawFrequenciesMatchTheConfiguredScale() {
        let cases: [(String, ProbabilityScale)] = [
            ("classic", .classic),
            ("sunny", ProbabilityScale(affirmative: 70, noncommittal: 20, negative: 10)),
            ("hard truth", ProbabilityScale(affirmative: 20, noncommittal: 25, negative: 55)),
            ("coin flip", ProbabilityScale(affirmative: 50, noncommittal: 0, negative: 50))
        ]

        let draws = 200_000
        for (name, scale) in cases {
            var generator = SeededGenerator(seed: 0xDEAD_BEEF)
            var counts: [Sentiment: Int] = [:]
            for _ in 0..<draws {
                let (sentiment, _) = Oracle.draw(scale: scale, using: &generator)
                counts[sentiment, default: 0] += 1
            }

            for sentiment in Sentiment.allCases {
                let observed = Double(counts[sentiment, default: 0]) / Double(draws)
                XCTAssertEqual(
                    observed,
                    scale.weight(for: sentiment),
                    accuracy: 0.01,
                    "\(name)/\(sentiment.rawValue): expected \(scale.weight(for: sentiment)), saw \(observed)"
                )
            }
        }
    }

    func testZeroWeightVerdictNeverAppears() {
        let scale = ProbabilityScale(affirmative: 50, noncommittal: 0, negative: 50)
        var generator = SeededGenerator(seed: 7)
        for _ in 0..<50_000 {
            let (sentiment, _) = Oracle.draw(scale: scale, using: &generator)
            XCTAssertNotEqual(sentiment, .noncommittal)
        }
    }

    /// A "No" must never be shown next to a 70% chance of yes.
    func testLikelihoodAlwaysAgreesWithTheVerdict() {
        for seed in UInt64(0)..<200 {
            var generator = SeededGenerator(seed: seed)
            for _ in 0..<200 {
                let (sentiment, likelihood) = Oracle.draw(scale: .classic, using: &generator)
                XCTAssertGreaterThanOrEqual(likelihood, sentiment.likelihoodBand.lowerBound)
                XCTAssertLessThanOrEqual(likelihood, sentiment.likelihoodBand.upperBound)
                XCTAssertEqual(Sentiment.forLikelihood(likelihood), sentiment)
            }
        }
    }

    // MARK: - Determinism

    func testSameQuestionSameDayGivesSameAnswer() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let first = oracle.predict(question: "Will it rain?", scale: .classic, allowedPackIDs: allPacks, date: now)
        let second = oracle.predict(question: "Will it rain?", scale: .classic, allowedPackIDs: allPacks, date: now)

        XCTAssertEqual(first.answerText, second.answerText)
        XCTAssertEqual(first.sentiment, second.sentiment)
        XCTAssertEqual(first.likelihood, second.likelihood, accuracy: 1e-12)
    }

    func testQuestionIsNormalisedBeforeSeeding() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let plain = oracle.predict(question: "Will it rain?", scale: .classic, allowedPackIDs: allPacks, date: now)
        let messy = oracle.predict(question: "  WILL   it  rain!!  ", scale: .classic, allowedPackIDs: allPacks, date: now)
        XCTAssertEqual(plain.answerText, messy.answerText)
    }

    func testVariantProducesADifferentDraw() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let question = "Should I take the job?"
        let readings = (0..<8).map {
            oracle.predict(question: question, scale: .classic, allowedPackIDs: allPacks, date: now, variant: $0)
        }
        // Not all eight re-rolls should collapse onto one answer.
        XCTAssertGreaterThan(Set(readings.map(\.answerText)).count, 1)
    }

    func testDifferentDaysGiveIndependentDraws() {
        let day1 = Date(timeIntervalSinceReferenceDate: 700_000_000)
        var sentiments: Set<Sentiment> = []
        for offset in 0..<40 {
            let date = day1.addingTimeInterval(Double(offset) * 86_400)
            sentiments.insert(
                oracle.predict(question: "Same question", scale: .classic, allowedPackIDs: allPacks, date: date).sentiment
            )
        }
        XCTAssertGreaterThan(sentiments.count, 1, "the orb froze across 40 days")
    }

    // MARK: - Pack gating

    func testFreeUsersOnlyEverSeeClassicAnswers() {
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        for offset in 0..<500 {
            let reading = oracle.predict(
                question: "Question \(offset)",
                scale: .classic,
                allowedPackIDs: freePacks,
                date: start.addingTimeInterval(Double(offset) * 3600)
            )
            XCTAssertEqual(reading.packID, AnswerCatalog.classicPackID)
        }
    }

    func testProUsersCanReachProPacks() {
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        var seenPacks: Set<String> = []
        for offset in 0..<800 {
            let reading = oracle.predict(
                question: "Question \(offset)",
                scale: .classic,
                allowedPackIDs: allPacks,
                date: start.addingTimeInterval(Double(offset) * 3600)
            )
            seenPacks.insert(reading.packID)
        }
        XCTAssertEqual(seenPacks, AnswerCatalog.allPackIDs)
    }

    /// A lapsed subscription can leave the selection empty mid-session; the orb
    /// must keep answering rather than dead-end.
    func testEmptyPackSelectionFallsBackToClassic() {
        let reading = oracle.predict(
            question: "Anyone home?",
            scale: .classic,
            allowedPackIDs: [],
            date: Date(timeIntervalSinceReferenceDate: 700_000_000)
        )
        XCTAssertEqual(reading.packID, AnswerCatalog.classicPackID)
        XCTAssertFalse(reading.answerText.isEmpty)
    }

    func testChangingPacksDoesNotChangeTheOdds() {
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        var freeYes = 0
        var proYes = 0
        let trials = 4_000

        for offset in 0..<trials {
            let date = start.addingTimeInterval(Double(offset) * 3600)
            let question = "Trial \(offset)"
            if oracle.predict(question: question, scale: .classic, allowedPackIDs: freePacks, date: date).sentiment == .affirmative {
                freeYes += 1
            }
            if oracle.predict(question: question, scale: .classic, allowedPackIDs: allPacks, date: date).sentiment == .affirmative {
                proYes += 1
            }
        }
        // Identical seeds and identical scale: the verdict stream must be identical.
        XCTAssertEqual(freeYes, proYes)
    }

    // MARK: - Catalog integrity

    func testEveryPackCanServeEveryVerdict() {
        for pack in AnswerCatalog.all {
            XCTAssertTrue(pack.isComplete, "\(pack.id) is missing a verdict")
        }
    }

    func testAnswerIDsAreGloballyUnique() {
        let ids = AnswerCatalog.all.flatMap { $0.answers.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testClassicPackIsTheCanonicalTwenty() {
        XCTAssertEqual(AnswerCatalog.classic.answers.count, 20)
        XCTAssertEqual(AnswerCatalog.classic.answers(for: .affirmative).count, 10)
        XCTAssertEqual(AnswerCatalog.classic.answers(for: .noncommittal).count, 5)
        XCTAssertEqual(AnswerCatalog.classic.answers(for: .negative).count, 5)
    }

    func testClassicIsTheOnlyFreePack() {
        XCTAssertEqual(AnswerCatalog.freePackIDs, [AnswerCatalog.classicPackID])
        XCTAssertEqual(AnswerCatalog.availablePackIDs(isPro: true), AnswerCatalog.allPackIDs)
    }

    // MARK: - Normalisation

    func testNormalizeStripsPunctuationCaseAndExtraSpace() {
        XCTAssertEqual(Oracle.normalize("  Will   I,  though?? "), "will i though")
        XCTAssertEqual(Oracle.normalize("!!!"), "")
        XCTAssertEqual(Oracle.normalize(""), "")
    }
}
