import XCTest
@testable import OrbCore

final class TopicScreenerTests: XCTestCase {

    private func topic(_ question: String) -> SensitiveTopic? {
        TopicScreener.screen(question)?.topic
    }

    // MARK: - The questions that must never get a random answer

    func testSelfHarmIsCaught() {
        let questions = [
            "should i kill myself",
            "Should I kill myself?",
            "is everyone better off dead without me",
            "should i end it all tonight",
            "am i suicidal",
            "should i hurt myself",
            "do i want to die",
            "should i cut myself",
            "is there no reason to live",
            "should i kms",
        ]
        for question in questions {
            XCTAssertEqual(topic(question), .selfHarm, "missed: \(question)")
        }
    }

    func testViolenceIsCaught() {
        let questions = [
            "should i kill him",
            "should i hurt someone",
            "should i beat up my neighbour",
            "should i get revenge",
            "will i murder him",
            "should i stab them",
        ]
        for question in questions {
            XCTAssertEqual(topic(question), .violence, "missed: \(question)")
        }
    }

    func testAbuseIsCaught() {
        let questions = [
            "my boyfriend hits me should i stay",
            "is my relationship abusive",
            "he keeps threatening me should i leave",
            "should i report that he assaulted me",
        ]
        for question in questions {
            XCTAssertEqual(topic(question), .abuse, "missed: \(question)")
        }
    }

    func testMedicalIsCaught() {
        let questions = [
            "do i have cancer",
            "should i stop taking my antidepressants",
            "should i go to the er",
            "am i pregnant",
            "should i skip my medication today",
        ]
        for question in questions {
            XCTAssertEqual(topic(question), .medical, "missed: \(question)")
        }
    }

    /// Every declined topic must actually decline — a warning is not enough for
    /// these, no matter what the copy says.
    func testDangerousTopicsDeclineRatherThanWarn() {
        for topic in [SensitiveTopic.selfHarm, .violence, .abuse, .medical] {
            XCTAssertEqual(topic.outcome, .decline, "\(topic) must not be answerable")
        }
    }

    func testLegalAndMoneyWarnButStillAnswer() {
        XCTAssertEqual(topic("should i sue my landlord"), .legal)
        XCTAssertEqual(topic("should i invest my life savings"), .money)
        XCTAssertEqual(SensitiveTopic.legal.outcome, .caution)
        XCTAssertEqual(SensitiveTopic.money.outcome, .caution)
    }

    // MARK: - False positives

    /// A screener that fires on ordinary questions gets ignored, which makes it
    /// useless when it matters. These are the idioms most likely to trip a
    /// naive keyword list.
    func testEverydayQuestionsAreNotBlocked() {
        let questions = [
            "should i get a dog",
            "will it rain tomorrow",
            "should i kill this feature",
            "will i kill it at the interview",
            "is this deadline killing the team",
            "should i cut my hair",
            "should i cut the cord on cable",
            "will my team beat them on saturday",
            "should i shoot my shot",
            "is that a dead end",
            "should i take the red pill or the blue one",
            "am i dying of boredom",
            "should i attack this problem differently",
            "will the stock market open tomorrow",
            "should i order pizza",
            "does she like me",
            "should i text him back",
            "will i pass my exam",
            "will i die alone",
            "should i go to the gym",
        ]
        for question in questions {
            XCTAssertNil(topic(question), "false positive on: \(question)")
        }
    }

    func testMatchingIsOnWholeWordsNotSubstrings() {
        // "i kms" is a self-harm phrase; kilometres must not trip it, which is
        // why the pronoun is part of the phrase rather than "kms" alone.
        XCTAssertNil(topic("is it 5 kms to the shop"))
        XCTAssertNil(topic("how many kms is the marathon"))
        XCTAssertEqual(topic("should i kms"), .selfHarm)
        // "sue" is a legal phrase; a name must not trip it.
        XCTAssertNil(topic("will susan call me back"))
        // "od on my" must not fire inside another word.
        XCTAssertNil(topic("should i buy a new modem"))
    }

    // MARK: - Behaviour

    func testEmptyAndBlankQuestionsPassThrough() {
        XCTAssertNil(topic(""))
        XCTAssertNil(topic("   "))
        XCTAssertNil(topic("???"))
    }

    func testPunctuationAndCaseDoNotEvadeTheScreener() {
        XCTAssertEqual(topic("SHOULD I KILL MYSELF?!"), .selfHarm)
        XCTAssertEqual(topic("should... i... kill... myself"), .selfHarm)
        XCTAssertEqual(topic("  should i   kill   myself  "), .selfHarm)
    }

    /// A question touching two topics resolves to the more serious one.
    func testMostSeriousTopicWins() {
        XCTAssertEqual(topic("should i stop taking my pills and end it all"), .selfHarm)
        XCTAssertEqual(topic("should i sue him or hurt him"), .violence)
    }

    func testDeclinedTopicsAlwaysOfferSomewhereToGo() {
        for topic in SensitiveTopic.allCases where topic.outcome == .decline {
            let screening = Screening(topic: topic)
            XCTAssertFalse(screening.headline.isEmpty)
            XCTAssertFalse(screening.message.isEmpty)

            // Medical points at a professional in prose; the crisis topics must
            // hand over an actual contactable resource.
            if topic != .medical {
                XCTAssertFalse(screening.resources.isEmpty, "\(topic) offers no resource")
            }
        }
    }

    func testEveryLinkedResourceHasAValidURL() {
        for topic in SensitiveTopic.allCases {
            for resource in Screening(topic: topic).resources {
                guard resource.urlString != nil else { continue }
                XCTAssertNotNil(resource.url, "\(resource.id) has an unparseable URL")
                XCTAssertTrue(resource.url?.scheme == "https", "\(resource.id) must be https")
            }
        }
    }

    func testDisclaimerIsPresentAndSpecific() {
        XCTAssertFalse(Disclaimer.title.isEmpty)
        XCTAssertFalse(Disclaimer.short.isEmpty)
        XCTAssertGreaterThanOrEqual(Disclaimer.points.count, 4)
        for point in Disclaimer.points {
            XCTAssertFalse(point.heading.isEmpty)
            XCTAssertFalse(point.body.isEmpty)
        }
    }
}
