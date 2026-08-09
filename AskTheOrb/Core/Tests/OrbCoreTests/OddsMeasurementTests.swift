import XCTest
@testable import OrbCore

final class OddsMeasurementTests: XCTestCase {

    // MARK: - The guarantee

    /// The whole design rests on this: every pack has the identical shape, so
    /// the measured odds cannot move no matter which packs are switched on.
    /// If a new pack is added with a different composition, this fails.
    func testEveryPackHasTheIdenticalComposition() {
        for pack in AnswerCatalog.all {
            XCTAssertEqual(
                pack.measurement,
                OddsMeasurement.perPack,
                "\(pack.id) is \(pack.measurement.affirmative)/\(pack.measurement.noncommittal)/\(pack.measurement.negative), not 10/5/5"
            )
            XCTAssertEqual(pack.answers.count, 20, "\(pack.id) does not have 20 answers")
        }
    }

    /// Every possible combination of packs must measure to the same ratio.
    func testOddsAreIdenticalForEverySubsetOfPacks() {
        let ids = Array(AnswerCatalog.allPackIDs)
        let expected = OddsMeasurement.perPack.percentages

        // All 2^6 - 1 non-empty subsets.
        for mask in 1..<(1 << ids.count) {
            var subset: Set<String> = []
            for (index, id) in ids.enumerated() where mask & (1 << index) != 0 {
                subset.insert(id)
            }
            let odds = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: subset)
            XCTAssertEqual(odds.percentages.affirmative, expected.affirmative, "subset \(subset)")
            XCTAssertEqual(odds.ratioDescription, "2 : 1 : 1", "subset \(subset)")
            XCTAssertEqual(odds.probability(of: .affirmative), 0.5, accuracy: 1e-12)
        }
    }

    /// An empty selection falls back to Classic rather than measuring zero.
    func testEmptySelectionStillMeasuresRealOdds() {
        let odds = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: [])
        XCTAssertEqual(odds, OddsMeasurement.perPack)
        XCTAssertEqual(odds.total, 20)
    }

    // MARK: - Presentation

    func testChanceDescriptionCountsRatherThanEstimates() {
        let odds = OddsMeasurement.measure(packs: AnswerCatalog.all, allowedPackIDs: ["classic"])
        XCTAssertEqual(odds.chanceDescription(of: .affirmative), "10 in 20")
        XCTAssertEqual(odds.chanceDescription(of: .noncommittal), "5 in 20")
        XCTAssertEqual(odds.chanceDescription(of: .negative), "5 in 20")
    }

    func testPercentagesAlwaysSumToOneHundred() {
        let cases: [(Int, Int, Int)] = [
            (10, 5, 5), (1, 1, 1), (2, 1, 1), (7, 2, 1), (0, 0, 1), (33, 33, 34), (1, 0, 0),
        ]
        for (a, n, g) in cases {
            let odds = OddsMeasurement(affirmative: a, noncommittal: n, negative: g)
            let p = odds.percentages
            XCTAssertEqual(p.affirmative + p.noncommittal + p.negative, 100, "\(a)/\(n)/\(g)")
        }
    }

    func testRatioIsReducedToLowestTerms() {
        XCTAssertEqual(OddsMeasurement(affirmative: 10, noncommittal: 5, negative: 5).ratioDescription, "2 : 1 : 1")
        XCTAssertEqual(OddsMeasurement(affirmative: 60, noncommittal: 30, negative: 30).ratioDescription, "2 : 1 : 1")
        XCTAssertEqual(OddsMeasurement(affirmative: 7, noncommittal: 2, negative: 1).ratioDescription, "7 : 2 : 1")
    }

    func testEmptyMeasurementDoesNotDivideByZero() {
        let empty = OddsMeasurement(affirmative: 0, noncommittal: 0, negative: 0)
        XCTAssertEqual(empty.total, 0)
        XCTAssertEqual(empty.probability(of: .affirmative), 0)
        XCTAssertEqual(empty.percentages.affirmative, 0)
    }

    func testNegativeCountsAreClamped() {
        let odds = OddsMeasurement(affirmative: -5, noncommittal: 5, negative: 5)
        XCTAssertEqual(odds.affirmative, 0)
        XCTAssertEqual(odds.total, 10)
    }

    func testRoundTripsThroughCodable() throws {
        let odds = OddsMeasurement.perPack
        let data = try JSONEncoder().encode(odds)
        XCTAssertEqual(try JSONDecoder().decode(OddsMeasurement.self, from: data), odds)
    }

    // MARK: - Observed odds

    func testObservedOddsTallyResults() {
        let observed = ObservedOdds(sentiments: [.affirmative, .affirmative, .negative, .noncommittal])
        XCTAssertEqual(observed.total, 4)
        XCTAssertEqual(observed.count(of: .affirmative), 2)
        XCTAssertEqual(observed.rate(of: .affirmative), 0.5, accuracy: 1e-12)
    }

    func testDriftIsSignedAndInPercentagePoints() {
        let expected = OddsMeasurement.perPack   // 50% yes
        let hot = ObservedOdds(affirmative: 6, noncommittal: 2, negative: 2)  // 60% yes
        XCTAssertEqual(hot.drift(from: expected, for: .affirmative), 10, accuracy: 1e-9)

        let cold = ObservedOdds(affirmative: 4, noncommittal: 3, negative: 3)  // 40% yes
        XCTAssertEqual(cold.drift(from: expected, for: .affirmative), -10, accuracy: 1e-9)
    }

    func testSmallSamplesAreNotTreatedAsMeaningful() {
        XCTAssertFalse(ObservedOdds(affirmative: 3).isMeaningful)
        XCTAssertFalse(ObservedOdds(affirmative: 10, negative: 9).isMeaningful)
        XCTAssertTrue(ObservedOdds(affirmative: 10, noncommittal: 5, negative: 5).isMeaningful)
    }

    /// The stated wobble should shrink as the sample grows — that's the whole
    /// reason the sample size is shown next to the rate.
    func testStandardErrorShrinksWithSampleSize() {
        let expected = OddsMeasurement.perPack
        let small = ObservedOdds(affirmative: 10, noncommittal: 5, negative: 5)     // n = 20
        let large = ObservedOdds(affirmative: 500, noncommittal: 250, negative: 250) // n = 1000

        let smallError = small.standardErrorPoints(for: .affirmative, expected: expected)
        let largeError = large.standardErrorPoints(for: .affirmative, expected: expected)

        XCTAssertEqual(smallError, 11.18, accuracy: 0.01)
        XCTAssertLessThan(largeError, smallError)
        XCTAssertEqual(largeError, 1.58, accuracy: 0.01)
    }

    func testEmptyObservationsAreInert() {
        let none = ObservedOdds()
        XCTAssertEqual(none.total, 0)
        XCTAssertEqual(none.rate(of: .affirmative), 0)
        XCTAssertEqual(none.drift(from: .perPack, for: .affirmative), 0)
        XCTAssertFalse(none.isMeaningful)
    }
}
