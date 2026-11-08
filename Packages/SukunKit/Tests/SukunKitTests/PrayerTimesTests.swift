import XCTest
@testable import SukunKit

/// Reference values: independent calculation by api.aladhan.com for the same parameters.
/// Adhan adds small per-method safety adjustments (e.g. +1 min Dhuhr for MWL), so we allow ±2 minutes.
final class PrayerTimesTests: XCTestCase {
    private let tolerance: TimeInterval = 2 * 60

    private func assertSchedule(
        _ location: StoredLocation,
        _ settings: SukunSettings,
        _ y: Int, _ m: Int, _ d: Int,
        _ expected: [PrayerKind: (Int, Int)],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let calculator = PrayerCalculator(location: location, settings: settings)
        let noon = Fixtures.date(y, m, d, 12, tz: location.timeZoneIdentifier)
        guard let schedule = calculator.schedule(for: noon) else {
            return XCTFail("No schedule", file: file, line: line)
        }
        XCTAssertEqual(schedule.slots.map(\.kind), PrayerKind.allCases, file: file, line: line)
        for (kind, (h, min)) in expected {
            let want = Fixtures.date(y, m, d, h, min, tz: location.timeZoneIdentifier)
            guard let got = schedule.time(for: kind) else {
                XCTFail("Missing \(kind)", file: file, line: line); continue
            }
            XCTAssertEqual(
                got.timeIntervalSince1970, want.timeIntervalSince1970, accuracy: tolerance,
                "\(location.displayName) \(kind): got \(got), want \(want)", file: file, line: line
            )
        }
    }

    func testMunichWinterMuslimWorldLeague() {
        assertSchedule(Fixtures.munich, Fixtures.settings(method: .muslimWorldLeague), 2026, 12, 15, [
            .fajr: (6, 3), .sunrise: (7, 57), .dhuhr: (12, 9), .asr: (14, 3), .maghrib: (16, 20), .isha: (18, 8),
        ])
    }

    func testMunichWinterHanafiAsr() {
        assertSchedule(Fixtures.munich, Fixtures.settings(method: .muslimWorldLeague, madhab: .hanafi), 2026, 12, 15, [
            .asr: (14, 36),
        ])
    }

    func testMunichAutumnMuslimWorldLeague() {
        assertSchedule(Fixtures.munich, Fixtures.settings(method: .muslimWorldLeague), 2026, 10, 15, [
            .fajr: (5, 49), .sunrise: (7, 33), .dhuhr: (12, 59), .asr: (15, 54), .maghrib: (18, 25), .isha: (20, 3),
        ])
    }

    func testMunichAutumnDiyanet() {
        assertSchedule(Fixtures.munich, Fixtures.settings(method: .turkey), 2026, 10, 15, [
            .fajr: (5, 49), .sunrise: (7, 26), .dhuhr: (13, 4), .asr: (15, 58), .maghrib: (18, 32), .isha: (20, 3),
        ])
    }

    func testMeccaWinterUmmAlQura() {
        assertSchedule(Fixtures.mecca, Fixtures.settings(method: .ummAlQura), 2026, 12, 15, [
            .fajr: (5, 29), .sunrise: (6, 51), .dhuhr: (12, 16), .asr: (15, 20), .maghrib: (17, 41), .isha: (19, 11),
        ])
    }

    func testMeccaSummerUmmAlQura() {
        assertSchedule(Fixtures.mecca, Fixtures.settings(method: .ummAlQura), 2026, 6, 15, [
            .fajr: (4, 10), .sunrise: (5, 38), .dhuhr: (12, 21), .asr: (15, 41), .maghrib: (19, 4), .isha: (20, 34),
        ])
    }

    func testUmmAlQuraIshaIsNinetyMinutesAfterMaghrib() {
        let calculator = PrayerCalculator(location: Fixtures.mecca, settings: Fixtures.settings(method: .ummAlQura))
        let schedule = calculator.schedule(for: Fixtures.date(2026, 6, 15, 12, tz: "Asia/Riyadh"))!
        XCTAssertEqual(schedule.time(for: .isha)!.timeIntervalSince(schedule.time(for: .maghrib)!), 90 * 60, accuracy: 60)
    }

    func testAutomaticMethodResolvesByCountry() {
        let settings = SukunSettings()
        XCTAssertEqual(CalculationConfiguration(settings: settings, location: Fixtures.mecca).method, .ummAlQura)
        XCTAssertEqual(CalculationConfiguration(settings: settings, location: Fixtures.munich).method, .muslimWorldLeague)
        XCTAssertEqual(CalculationConfiguration(settings: settings, location: Fixtures.munich).highLatitude, .seventhOfTheNight)
        XCTAssertEqual(CalculationConfiguration(settings: settings, location: Fixtures.mecca).highLatitude, .middleOfTheNight)
        XCTAssertEqual(RegionalDefaults.method(forCountryCode: "tr"), .turkey)
        XCTAssertEqual(RegionalDefaults.madhab(forCountryCode: "PK"), .hanafi)
        XCTAssertEqual(RegionalDefaults.method(forCountryCode: nil), .muslimWorldLeague)
    }

    func testHighLatitudeSummerProducesOrderedTimes() {
        // Oslo, midsummer: Fajr/Isha angles are never reached; the high-latitude rule must still yield an ordered day.
        let oslo = StoredLocation(coordinate: Coordinate(latitude: 59.91, longitude: 10.75), countryCode: "NO",
                                  timeZoneIdentifier: "Europe/Oslo", source: .manual)
        let calculator = PrayerCalculator(location: oslo, settings: SukunSettings())
        let schedule = calculator.schedule(for: Fixtures.date(2026, 6, 21, 12, tz: "Europe/Oslo"))
        XCTAssertNotNil(schedule)
        let dates = schedule!.slots.map(\.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testNextAndPreviousAcrossMidnight() {
        let calculator = PrayerCalculator(location: Fixtures.munich, settings: Fixtures.settings(method: .muslimWorldLeague))
        let lateNight = Fixtures.date(2026, 12, 15, 23, 30, tz: "Europe/Berlin")
        let next = calculator.next(after: lateNight)!
        XCTAssertEqual(next.kind, .fajr)
        XCTAssertEqual(next.date.timeIntervalSince(Fixtures.date(2026, 12, 16, 6, 3, tz: "Europe/Berlin")), 0, accuracy: 120)
        XCTAssertEqual(calculator.previous(atOrBefore: lateNight)?.kind, .isha)

        let afterMidnight = Fixtures.date(2026, 12, 16, 0, 30, tz: "Europe/Berlin")
        XCTAssertEqual(calculator.previous(atOrBefore: afterMidnight)?.kind, .isha)
        XCTAssertEqual(calculator.period(at: afterMidnight), .night)
    }

    func testNextSkipsSunriseByDefault() {
        let calculator = PrayerCalculator(location: Fixtures.munich, settings: Fixtures.settings(method: .muslimWorldLeague))
        let afterFajr = Fixtures.date(2026, 12, 15, 7, 0, tz: "Europe/Berlin")
        XCTAssertEqual(calculator.next(after: afterFajr)?.kind, .dhuhr)
        XCTAssertEqual(calculator.next(after: afterFajr, includeSunrise: true)?.kind, .sunrise)
    }
}
