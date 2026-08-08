import XCTest
@testable import EightBallCore

final class AskAllowanceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private let noon = Date(timeIntervalSinceReferenceDate: 700_000_000)

    func testFreeUserGetsExactlyTheDailyLimit() {
        var allowance = AskAllowance()
        for remaining in stride(from: FreeTier.dailyQuestionLimit, to: 0, by: -1) {
            XCTAssertEqual(allowance.remaining(isPro: false, on: noon, calendar: calendar), remaining)
            XCTAssertTrue(allowance.consume(isPro: false, on: noon, calendar: calendar))
        }
        XCTAssertEqual(allowance.remaining(isPro: false, on: noon, calendar: calendar), 0)
        XCTAssertFalse(allowance.canAsk(isPro: false, on: noon, calendar: calendar))
    }

    func testExhaustedAllowanceRejectsWithoutMutating() {
        var allowance = AskAllowance()
        for _ in 0..<FreeTier.dailyQuestionLimit {
            allowance.consume(isPro: false, on: noon, calendar: calendar)
        }
        let before = allowance
        XCTAssertFalse(allowance.consume(isPro: false, on: noon, calendar: calendar))
        XCTAssertEqual(allowance, before)
    }

    func testAllowanceRefillsTheNextDay() {
        var allowance = AskAllowance()
        for _ in 0..<FreeTier.dailyQuestionLimit {
            allowance.consume(isPro: false, on: noon, calendar: calendar)
        }
        XCTAssertFalse(allowance.canAsk(isPro: false, on: noon, calendar: calendar))

        let tomorrow = noon.addingTimeInterval(86_400)
        XCTAssertEqual(allowance.remaining(isPro: false, on: tomorrow, calendar: calendar), FreeTier.dailyQuestionLimit)
        XCTAssertTrue(allowance.consume(isPro: false, on: tomorrow, calendar: calendar))
        XCTAssertEqual(allowance.remaining(isPro: false, on: tomorrow, calendar: calendar), FreeTier.dailyQuestionLimit - 1)
    }

    /// Clock changes and travel can move "today" backwards; that must reset the
    /// counter rather than silently granting or denying asks.
    func testMovingBackwardsInTimeAlsoRolls() {
        var allowance = AskAllowance()
        for _ in 0..<FreeTier.dailyQuestionLimit {
            allowance.consume(isPro: false, on: noon, calendar: calendar)
        }
        let yesterday = noon.addingTimeInterval(-86_400)
        XCTAssertTrue(allowance.consume(isPro: false, on: yesterday, calendar: calendar))
    }

    func testProIsNeverLimited() {
        var allowance = AskAllowance()
        XCTAssertNil(allowance.remaining(isPro: true, on: noon, calendar: calendar))
        for _ in 0..<500 {
            XCTAssertTrue(allowance.consume(isPro: true, on: noon, calendar: calendar))
        }
        XCTAssertTrue(allowance.canAsk(isPro: true, on: noon, calendar: calendar))
    }

    /// If a subscription lapses mid-day the user shouldn't get a fresh five on
    /// top of the questions they already asked as a subscriber.
    func testLapsedSubscriptionKeepsTheDaysUsage() {
        var allowance = AskAllowance()
        for _ in 0..<3 {
            allowance.consume(isPro: true, on: noon, calendar: calendar)
        }
        XCTAssertEqual(allowance.remaining(isPro: false, on: noon, calendar: calendar), FreeTier.dailyQuestionLimit - 3)
    }

    func testSecondsUntilResetIsBoundedByADay() {
        let allowance = AskAllowance()
        let seconds = allowance.secondsUntilReset(on: noon, calendar: calendar)
        XCTAssertGreaterThan(seconds, 0)
        XCTAssertLessThanOrEqual(seconds, 86_400)
    }

    func testRoundTripsThroughCodable() throws {
        var allowance = AskAllowance()
        allowance.consume(isPro: false, on: noon, calendar: calendar)
        let data = try JSONEncoder().encode(allowance)
        let decoded = try JSONDecoder().decode(AskAllowance.self, from: data)
        XCTAssertEqual(decoded, allowance)
    }
}
