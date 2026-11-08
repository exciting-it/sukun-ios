import XCTest
@testable import Sukun
@testable import SukunKit

final class NotificationContentTests: XCTestCase {
    private let formatter = PrayerTimeFormatter(clockFormat: .twentyFourHour, timeZone: TimeZone(identifier: "Europe/Berlin")!,
                                                locale: Locale(identifier: "en_US"))
    private let date = Fixtures.date(2026, 12, 15, 16, 43, tz: "Europe/Berlin")

    private func text(_ content: PlannedNotification.Content) -> (title: String, body: String) {
        NotificationText.content(for: PlannedNotification(id: "sukun.test", fireDate: date, content: content),
                                 formatter: formatter)
    }

    func testPrayer() {
        let t = text(.prayer(PrayerSlot(kind: .maghrib, date: date), ramadan: nil))
        XCTAssertEqual(t.title, "Maghrib")
        XCTAssertEqual(t.body, "It’s time for Maghrib · 16:43")
    }

    func testRamadanVariants() {
        XCTAssertEqual(text(.prayer(PrayerSlot(kind: .fajr, date: date), ramadan: .suhoorEnded)).body, "Suhoor has ended · 16:43")
        XCTAssertEqual(text(.prayer(PrayerSlot(kind: .maghrib, date: date), ramadan: .iftar)).body, "Time for Iftar · 16:43")
    }

    func testEarly() {
        let t = text(.early(PrayerSlot(kind: .maghrib, date: date), minutes: 15))
        XCTAssertEqual(t.title, "Maghrib")
        XCTAssertEqual(t.body, "Maghrib in 15 min · 16:43")
    }

    func testJumuah() {
        let t = text(.jumuah(dhuhr: PrayerSlot(kind: .dhuhr, date: date)))
        XCTAssertEqual(t.title, "Jumu'ah")
        XCTAssertEqual(t.body, "Today · Dhuhr 16:43")
    }

    func testSuhoor() {
        let t = text(.suhoor(fajr: PrayerSlot(kind: .fajr, date: date), minutes: 30))
        XCTAssertEqual(t.title, "Suhoor")
        XCTAssertEqual(t.body, "Suhoor ends in 30 min · Fajr 16:43")
    }
}
