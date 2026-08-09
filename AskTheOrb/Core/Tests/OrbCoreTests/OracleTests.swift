import XCTest
@testable import OrbCore

final class OracleTests: XCTestCase {

    private let oracle = Oracle()
    private let allPacks = AnswerCatalog.allPackIDs
    private let freePacks = AnswerCatalog.freePackIDs

    // MARK: - The number on screen is the number that happens

    /// The product promise: the stated chance of yes is the observed rate. Draw
    /// a lot, count the verdicts, compare against the measurement the app shows.
    func testObservedFrequenciesMatchTheMeasuredOdds() {
        for packs in [freePacks, allPacks] {
            let expected = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: packs)
            var generator = SeededGenerator(seed: 0xDEAD_BEEF)
            var counts: [Sentiment: Int] = [:]

            let draws = 200_000
            for _ in 0..<draws {
                let reading = oracle.predict(
                    question: "trial",
                    allowedPackIDs: packs,
                    using: &generator
                )
                counts[reading.sentiment, default: 0] += 1
            }

            for sentiment in Sentiment.allCases {
                let observed = Double(counts[sentiment, default: 0]) / Double(draws)
                XCTAssertEqual(
                    observed,
                    expected.probability(of: sentiment),
                    accuracy: 0.01,
                    "\(sentiment): expected \(expected.probability(of: sentiment)), saw \(observed)"
                )
            }
        }
    }

    /// Enabling every Pro pack must not move the odds by a single point.
    func testPacksChangeTheVocabularyAndNotTheOdds() {
        let free = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: freePacks)
        let pro = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: allPacks)

        XCTAssertEqual(free.percentages, pro.percentages)
        XCTAssertEqual(free.ratioDescription, pro.ratioDescription)
        XCTAssertEqual(free.probability(of: .affirmative), pro.probability(of: .affirmative), accuracy: 1e-12)
        XCTAssertGreaterThan(pro.total, free.total, "Pro should offer more answers, just not better ones")
    }

    /// Every reading carries the odds that produced it, so history stays honest
    /// even if the pack selection changes later.
    func testPredictionCarriesTheOddsItWasDrawnFrom() {
        let reading = oracle.predict(
            question: "does this record the odds",
            allowedPackIDs: freePacks,
            date: Date(timeIntervalSinceReferenceDate: 700_000_000)
        )
        XCTAssertEqual(reading.odds, OddsMeasurement.perPack)
        XCTAssertEqual(reading.yesChancePercent, 50)
        XCTAssertEqual(reading.chanceDescription, reading.odds.chanceDescription(of: reading.sentiment))
    }

    // MARK: - Determinism

    func testSameQuestionSameDayGivesSameAnswer() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let first = oracle.predict(question: "Will it rain?", allowedPackIDs: allPacks, date: now)
        let second = oracle.predict(question: "Will it rain?", allowedPackIDs: allPacks, date: now)

        XCTAssertEqual(first.answerText, second.answerText)
        XCTAssertEqual(first.sentiment, second.sentiment)
    }

    func testQuestionIsNormalisedBeforeSeeding() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let plain = oracle.predict(question: "Will it rain?", allowedPackIDs: allPacks, date: now)
        let messy = oracle.predict(question: "  WILL   it  rain!!  ", allowedPackIDs: allPacks, date: now)
        XCTAssertEqual(plain.answerText, messy.answerText)
    }

    func testVariantProducesADifferentDraw() {
        let now = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let readings = (0..<8).map {
            oracle.predict(question: "Should I take the job?", allowedPackIDs: allPacks, date: now, variant: $0)
        }
        XCTAssertGreaterThan(Set(readings.map(\.answerText)).count, 1)
    }

    func testDifferentDaysGiveIndependentDraws() {
        let day1 = Date(timeIntervalSinceReferenceDate: 700_000_000)
        var sentiments: Set<Sentiment> = []
        for offset in 0..<40 {
            sentiments.insert(
                oracle.predict(
                    question: "Same question",
                    allowedPackIDs: allPacks,
                    date: day1.addingTimeInterval(Double(offset) * 86_400)
                ).sentiment
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
                allowedPackIDs: freePacks,
                date: start.addingTimeInterval(Double(offset) * 3600)
            )
            XCTAssertEqual(reading.packID, AnswerCatalog.classicPackID)
        }
    }

    func testProUsersCanReachEveryPack() {
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        var seen: Set<String> = []
        for offset in 0..<800 {
            seen.insert(
                oracle.predict(
                    question: "Question \(offset)",
                    allowedPackIDs: allPacks,
                    date: start.addingTimeInterval(Double(offset) * 3600)
                ).packID
            )
        }
        XCTAssertEqual(seen, AnswerCatalog.allPackIDs)
    }

    /// A lapsed subscription can leave the selection empty mid-session; the orb
    /// must keep answering on real odds rather than dead-end.
    func testEmptyPackSelectionFallsBackToClassic() {
        let reading = oracle.predict(
            question: "Anyone home?",
            allowedPackIDs: [],
            date: Date(timeIntervalSinceReferenceDate: 700_000_000)
        )
        XCTAssertEqual(reading.packID, AnswerCatalog.classicPackID)
        XCTAssertEqual(reading.odds, OddsMeasurement.perPack)
        XCTAssertFalse(reading.answerText.isEmpty)
    }

    func testPoolSizeMatchesTheEnabledPacks() {
        XCTAssertEqual(oracle.answerPool(allowedPackIDs: freePacks).count, 20)
        XCTAssertEqual(oracle.answerPool(allowedPackIDs: allPacks).count, 20 * AnswerCatalog.all.count)
        XCTAssertEqual(oracle.answerPool(allowedPackIDs: []).count, 20)
    }

    // MARK: - Catalog integrity

    func testEveryPackCanServeEveryVerdict() {
        for pack in AnswerCatalog.all {
            XCTAssertTrue(pack.isComplete, "\(pack.id) is missing a verdict")
        }
    }

    func testAnswerIDsAndTextsAreUnique() {
        let ids = AnswerCatalog.all.flatMap { $0.answers.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)

        let texts = AnswerCatalog.all.flatMap { $0.answers.map(\.text) }
        XCTAssertEqual(Set(texts).count, texts.count, "duplicate answer text would skew the pool")
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
