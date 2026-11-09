import XCTest
@testable import Sukun

final class ReviewPromptTests: XCTestCase {
    private var berlin: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }
    private func day(_ d: Int, _ h: Int = 12) -> Date {
        berlin.date(from: DateComponents(year: 2027, month: 1, day: d, hour: h))!
    }
    private func store() -> ReviewPrompt {
        ReviewPrompt(defaults: UserDefaults(suiteName: "sukun.review.\(UUID().uuidString)")!, calendar: berlin)
    }

    /// Opens the app once on each of `days`.
    private func use(_ prompt: ReviewPrompt, days: [Int]) {
        for d in days { prompt.recordActiveDay(day(d)) }
    }

    func testAsksAfterSevenDaysOfUseAndTwoWeeks() {
        let p = store()
        use(p, days: [1, 2, 3, 4, 5, 6, 7])
        XCTAssertFalse(p.shouldAsk(now: day(7), version: "1.0.0", prayerIsRunning: true), "installed only 6 days ago")
        XCTAssertTrue(p.shouldAsk(now: day(15), version: "1.0.0", prayerIsRunning: true))
    }

    func testSameDayCountsOnceAndFewDaysAreNotEnough() {
        let p = store()
        for h in 8...20 { p.recordActiveDay(day(1, h)) }
        use(p, days: [2, 3, 4, 5, 6])
        XCTAssertEqual(p.activeDayCount, 6)
        XCTAssertFalse(p.shouldAsk(now: day(30), version: "1.0.0", prayerIsRunning: true))
    }

    func testOnlyWhileAPrayerIsRunning() {
        let p = store()
        use(p, days: Array(1...7))
        XCTAssertFalse(p.shouldAsk(now: day(20), version: "1.0.0", prayerIsRunning: false))
    }

    func testOncePerVersion() {
        let p = store()
        use(p, days: Array(1...7))
        p.recordAsked(version: "1.0.0")
        XCTAssertFalse(p.shouldAsk(now: day(20), version: "1.0.0", prayerIsRunning: true))
        XCTAssertTrue(p.shouldAsk(now: day(20), version: "1.1.0", prayerIsRunning: true))
    }

    func testNotSoonAfterReportingAProblem() {
        let p = store()
        use(p, days: Array(1...7))
        p.recordProblemReport(day(18))
        XCTAssertFalse(p.shouldAsk(now: day(20), version: "1.0.0", prayerIsRunning: true))
        XCTAssertTrue(p.shouldAsk(now: day(18 + 15), version: "1.0.0", prayerIsRunning: true))
    }
}
