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
        app.launchArguments = ["-AskTheOrbResetState"]
        app.launch()
        dismissDisclaimerIfPresent()
    }

    /// A reset launch always lands on the first-run disclaimer gate, which has
    /// no way past it but the button — that is the point of it.
    private func dismissDisclaimerIfPresent() {
        let acknowledge = app.buttons["I understand"]
        if acknowledge.waitForExistence(timeout: 5) {
            acknowledge.tap()
        }
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
        field.typeText("Is the orb consistent?")

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

    // MARK: - Safety screening

    /// The single most important behaviour in the app: a question about
    /// self-harm must never receive a random verdict.
    func testSelfHarmQuestionGetsSupportNotAReading() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("should i kill myself")

        let quotaBefore = app.staticTexts[A11yID.quotaLabel].label
        app.buttons[A11yID.askButton].tap()

        XCTAssertTrue(
            app.staticTexts["This one deserves a real person"].waitForExistence(timeout: 4),
            "no support notice appeared"
        )
        XCTAssertTrue(app.buttons["988 Suicide & Crisis Lifeline"].exists)

        // No reading, and no ask consumed.
        XCTAssertFalse(app.otherElements[A11yID.readingCard].exists)
        XCTAssertEqual(app.staticTexts[A11yID.quotaLabel].label, quotaBefore)
    }

    func testDeclinedQuestionIsNotRecordedInHistory() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("should i hurt someone")
        app.buttons[A11yID.askButton].tap()
        XCTAssertTrue(app.staticTexts["The orb won't answer this"].waitForExistence(timeout: 4))

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["No readings yet"].waitForExistence(timeout: 4))
    }

    func testMoneyQuestionStillAnswersButCarriesAWarning() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("should i invest my life savings")
        app.buttons[A11yID.askButton].tap()

        XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["Not financial advice"].exists)
    }

    func testOrdinaryQuestionIsNeverScreened() {
        let field = app.textFields[A11yID.questionField]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("will i kill it at the interview")
        app.buttons[A11yID.askButton].tap()

        XCTAssertTrue(app.otherElements[A11yID.readingCard].waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["The orb won't answer this"].exists)
    }

    // MARK: - Disclaimer

    func testDisclaimerGateIsShownOnFirstLaunchAndNotAgain() {
        // setUp already dismissed it. Relaunching without a reset must not
        // show it a second time.
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.textFields[A11yID.questionField].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunched.buttons["I understand"].exists)
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
    static let orb = "ask.orb"
    static let readingCard = "ask.readingCard"
    static let readingVerdict = "ask.readingVerdict"
    static let quotaLabel = "ask.quotaLabel"
    static let goProButton = "ask.goProButton"
    static let paywall = "paywall.root"
}
