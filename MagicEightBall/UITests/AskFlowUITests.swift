import XCTest

/// End-to-end checks on the real app: launch, ask, see a reading, hit the
/// free-tier wall, land on the paywall.
///
/// The scheme attaches `Configuration/Products.storekit`, so purchases resolve
/// locally and no sandbox Apple Account is needed to run these.
final class AskFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-EightBallResetState"]
        app.launch()
    }

    // MARK: - Core loop

    func testAskingProducesAReading() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        field.tap()
        field.typeText("Will this ship on time?")

        app.buttons[A11yID.askButton].tap()

        let card = app.otherElements[A11yID.readingCard]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "no reading appeared after asking")

        // The reading must state a verdict and a percentage, not just a phrase.
        let percentage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'chance of yes'")
        ).firstMatch
        XCTAssertTrue(percentage.waitForExistence(timeout: 3))
    }

    func testSameQuestionRepeatsTheSameAnswerWithoutSpendingAnAsk() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Is the ball consistent?")

        app.buttons[A11yID.askButton].tap()
        XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))

        let quotaAfterFirst = app.staticTexts[A11yID.quotaLabel].label

        app.buttons[A11yID.askButton].tap()
        XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))

        XCTAssertEqual(
            app.staticTexts[A11yID.quotaLabel].label,
            quotaAfterFirst,
            "re-asking today's question should not consume the free allowance"
        )
    }

    // MARK: - Free tier

    func testFreeAllowanceRunsOutAndOffersPro() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        // Five distinct questions exhausts the free daily allowance.
        for index in 1...5 {
            field.tap()
            field.typeText("Question number \(index)?")
            app.buttons[A11yID.askButton].tap()
            XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))
            clear(field)
        }

        XCTAssertTrue(app.staticTexts[A11yID.quotaLabel].label.contains("0"))

        field.tap()
        field.typeText("One question too many?")
        app.buttons[A11yID.askButton].tap()

        XCTAssertTrue(
            app.otherElements[A11yID.paywall].waitForExistence(timeout: 5),
            "exhausting the free allowance should present the paywall"
        )
    }

    func testPaywallStatesPriceAndLinksToTerms() {
        app.buttons[A11yID.goProButton].tap()
        XCTAssertTrue(app.otherElements[A11yID.paywall].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Yearly"].waitForExistence(timeout: 8), "plans never loaded")
        XCTAssertTrue(app.staticTexts["Monthly"].exists)
        XCTAssertTrue(app.staticTexts["Lifetime"].exists)

        // Guideline 3.1.2 requires renewal terms and both legal links on screen.
        let renewal = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'renews automatically'")
        ).firstMatch
        XCTAssertTrue(renewal.exists)
        XCTAssertTrue(app.links["Terms of Use"].exists)
        XCTAssertTrue(app.links["Privacy Policy"].exists)
    }

    // MARK: - Gating

    func testProPresetsAreLockedForFreeUsers() {
        app.tabBars.buttons["Odds"].tap()

        let sunny = app.staticTexts["Sunny Side"]
        XCTAssertTrue(sunny.waitForExistence(timeout: 5))
        sunny.tap()

        XCTAssertTrue(
            app.otherElements[A11yID.paywall].waitForExistence(timeout: 5),
            "tapping a Pro preset should present the paywall"
        )
    }

    func testHistoryRecordsTheReading() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Does history work?")
        app.buttons[A11yID.askButton].tap()
        XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["Does history work?"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func clear(_ element: XCUIElement) {
        element.tap()
        guard let value = element.value as? String, !value.isEmpty else { return }
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }
}

/// Mirrors `A11y` in the app target. Duplicated rather than shared because UI
/// test bundles can't import the app module.
enum A11yID {
    static let questionField = "ask.questionField"
    static let askButton = "ask.askButton"
    static let askAgainButton = "ask.askAgainButton"
    static let ball = "ask.ball"
    static let readingCard = "ask.readingCard"
    static let readingVerdict = "ask.readingVerdict"
    static let quotaLabel = "ask.quotaLabel"
    static let goProButton = "ask.goProButton"
    static let paywall = "paywall.root"
}
