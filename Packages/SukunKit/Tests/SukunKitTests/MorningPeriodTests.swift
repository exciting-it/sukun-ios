import XCTest
@testable import SukunKit

final class MorningPeriodTests: XCTestCase {
    private let tz = "Europe/Berlin"
    private var day: Date { Fixtures.date(2026, 12, 15, 12, tz: tz) }
    private let minute: TimeInterval = 60

    private func times(_ settings: SukunSettings) -> (sunrise: Date, dhuhr: Date) {
        let schedule = PrayerCalculator(location: Fixtures.munich, settings: settings).schedule(for: day)!
        return (schedule.time(for: .sunrise)!, schedule.time(for: .dhuhr)!)
    }

    private func morning(at date: Date, _ settings: SukunSettings) -> MorningPeriod? {
        PrayerSnapshot(date: date, location: Fixtures.munich, settings: settings)!.morning
    }

    func testSettingDefaultsOnAndDecodesFromOldJSON() throws {
        XCTAssertTrue(SukunSettings().showsMorningPeriods)
        let old = Data(#"{"method":"automatic","notificationsEnabled":["isha"]}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(SukunSettings.self, from: old).showsMorningPeriods)
        var s = SukunSettings()
        s.showsMorningPeriods = false
        XCTAssertFalse(try JSONDecoder().decode(SukunSettings.self, from: JSONEncoder().encode(s)).showsMorningPeriods)
    }

    func testPeriodsWithSettingOn() {
        let settings = Fixtures.settings(method: .muslimWorldLeague)
        let (s, d) = times(settings)

        let atSunrise = morning(at: s, settings)
        XCTAssertEqual(atSunrise?.kind, .sunrise)
        XCTAssertEqual(atSunrise?.start, s)
        XCTAssertEqual(atSunrise?.noPrayerUntil, s + 15 * minute)
        XCTAssertEqual(morning(at: s + 15 * minute - 1, settings)?.kind, .sunrise)

        let duha = morning(at: s + 15 * minute, settings)
        XCTAssertEqual(duha?.kind, .duha)
        XCTAssertEqual(duha?.start, s + 15 * minute)
        XCTAssertNil(duha?.noPrayerUntil)
        XCTAssertEqual(morning(at: d - 10 * minute - 1, settings)?.kind, .duha)

        let before = morning(at: d - 10 * minute, settings)
        XCTAssertEqual(before?.kind, .beforeDhuhr)
        XCTAssertEqual(before?.start, d - 10 * minute)
        XCTAssertEqual(before?.noPrayerUntil, d)
        XCTAssertEqual(morning(at: d - 1, settings)?.kind, .beforeDhuhr)

        XCTAssertNil(morning(at: d, settings), "Dhuhr is running")
        XCTAssertNil(morning(at: s - 1, settings), "Fajr is running")
    }

    func testSettingOffShowsOnlyMorning() {
        var settings = Fixtures.settings(method: .muslimWorldLeague)
        settings.showsMorningPeriods = false
        let (s, d) = times(settings)
        for t in [s, s + 15 * minute, d - 10 * minute, d - 1] {
            let m = morning(at: t, settings)
            XCTAssertEqual(m?.kind, .morning)
            XCTAssertEqual(m?.start, s)
            XCTAssertNil(m?.noPrayerUntil)
        }
        XCTAssertNil(morning(at: d, settings))
    }

    func testMorningIsTheCurrentStateNotDhuhr() {
        let settings = Fixtures.settings(method: .muslimWorldLeague)
        let (s, _) = times(settings)
        let snapshot = PrayerSnapshot(date: s + 60 * minute, location: Fixtures.munich, settings: settings)!
        XCTAssertNil(snapshot.current)
        XCTAssertEqual(snapshot.headline, MorningPeriod.Kind.duha.title)
        XCTAssertEqual(snapshot.headlineDate, s + 15 * minute)
    }

    func testShortMorningMergesIntoOneNoPrayerWindow() {
        let s = Fixtures.date(2026, 12, 15, 11, 0, tz: tz)
        let periods = MorningPeriod.periods(sunrise: s, dhuhr: s + 20 * minute, detailed: true)
        XCTAssertEqual(periods.map(\.kind), [.sunrise])
        XCTAssertEqual(periods.first?.noPrayerUntil, s + 20 * minute)
        XCTAssertEqual(MorningPeriod.periods(sunrise: s, dhuhr: s, detailed: true), [])
        XCTAssertEqual(MorningPeriod.periods(sunrise: s, dhuhr: s - minute, detailed: false), [])
    }

    func testTimelineSwitchesAtTheNewBoundaries() {
        let settings = Fixtures.settings(method: .muslimWorldLeague)
        let (s, d) = times(settings)
        let dates = PrayerTimeline.transitionDates(from: s - 3600, hours: 24, location: Fixtures.munich, settings: settings)
        XCTAssert(dates.contains(s + 15 * minute))
        XCTAssert(dates.contains(d - 10 * minute))

        var off = settings
        off.showsMorningPeriods = false
        let offDates = PrayerTimeline.transitionDates(from: s - 3600, hours: 24, location: Fixtures.munich, settings: off)
        XCTAssertFalse(offDates.contains(s + 15 * minute))
    }
}
