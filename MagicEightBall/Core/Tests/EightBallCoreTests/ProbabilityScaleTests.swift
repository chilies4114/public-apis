import XCTest
@testable import EightBallCore

final class ProbabilityScaleTests: XCTestCase {

    func testWeightsAreNormalised() {
        let scale = ProbabilityScale(affirmative: 10, noncommittal: 5, negative: 5)
        XCTAssertEqual(scale.affirmative, 0.5, accuracy: 1e-12)
        XCTAssertEqual(scale.noncommittal, 0.25, accuracy: 1e-12)
        XCTAssertEqual(scale.negative, 0.25, accuracy: 1e-12)
        XCTAssertEqual(scale.affirmative + scale.noncommittal + scale.negative, 1.0, accuracy: 1e-12)
    }

    func testNegativeAndNonFiniteInputsAreClamped() {
        let scale = ProbabilityScale(affirmative: -10, noncommittal: .nan, negative: 5)
        XCTAssertEqual(scale.affirmative, 0, accuracy: 1e-12)
        XCTAssertEqual(scale.noncommittal, 0, accuracy: 1e-12)
        XCTAssertEqual(scale.negative, 1, accuracy: 1e-12)
    }

    func testAllZeroWeightsFallBackToEvenSplit() {
        let scale = ProbabilityScale(affirmative: 0, noncommittal: 0, negative: 0)
        XCTAssertEqual(scale.affirmative, 1.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(scale.noncommittal, 1.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(scale.negative, 1.0 / 3.0, accuracy: 1e-12)
    }

    func testDisplayPercentagesAlwaysSumToOneHundred() {
        // Thirds round to 33/33/33 and would otherwise show 99.
        let thirds = ProbabilityScale(affirmative: 1, noncommittal: 1, negative: 1)
        let split = thirds.displayPercentages
        XCTAssertEqual(split.affirmative + split.noncommittal + split.negative, 100)

        for affirmative in stride(from: 0.0, through: 100.0, by: 1.0) {
            let remainder = 100 - affirmative
            let scale = ProbabilityScale(
                affirmative: affirmative,
                noncommittal: remainder / 2,
                negative: remainder / 2
            )
            let parts = scale.displayPercentages
            XCTAssertEqual(
                parts.affirmative + parts.noncommittal + parts.negative,
                100,
                "weights \(affirmative) did not sum to 100"
            )
        }
    }

    func testEveryPresetIsNormalisedAndOnlyClassicIsFree() {
        let free = ScalePreset.all.filter { !$0.requiresPro }
        XCTAssertEqual(free.map(\.id), ["classic"])

        for preset in ScalePreset.all {
            let total = preset.scale.affirmative + preset.scale.noncommittal + preset.scale.negative
            XCTAssertEqual(total, 1.0, accuracy: 1e-12, "\(preset.id) is not normalised")
        }
    }

    func testPresetIDsAreUnique() {
        let ids = ScalePreset.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
