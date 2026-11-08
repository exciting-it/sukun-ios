import XCTest
@testable import SukunKit

final class RamadanTests: XCTestCase {
    private let tz = TimeZone(identifier: "Europe/Berlin")!

    private var civil: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }

    /// Midnight (Berlin) of 1 Ramadan 1448 per Umm al-Qura, and of the last day of Ramadan.
    private var firstDay: Date {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = tz
        return hijri.date(from: DateComponents(year: 1448, month: 9, day: 1))!
    }

    private var lastDay: Date {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = tz
        let shawwal = hijri.date(from: DateComponents(year: 1448, month: 10, day: 1))!
        return civil.date(byAdding: .day, value: -1, to: shawwal)!
    }

    private func day(_ base: Date, _ offset: Int) -> Date { civil.date(byAdding: .day, value: offset, to: base)! }

    private func time(_ kind: PrayerKind, on day: Date, settings: SukunSettings) -> Date {
        PrayerCalculator(location: Fixtures.munich, settings: settings)
            .schedule(for: day.addingTimeInterval(12 * 3600))!.time(for: kind)!
    }

    private func settings(_ mode: RamadanMode = .automatic, hijri: Int = 0) -> SukunSettings {
        var s = Fixtures.settings(method: .muslimWorldLeague)
        s.ramadanMode = mode
        s.hijriAdjustmentDays = hijri
        return s
    }

    private func ramadan(at date: Date, _ s: SukunSettings) -> RamadanState.Countdown? {
        PrayerSnapshot(date: date, location: Fixtures.munich, settings: s)!.ramadan?.countdown
    }

    func testActivatesAtMaghribOnTheEve() {
        let s = settings()
        let eveMaghrib = time(.maghrib, on: day(firstDay, -1), settings: s)
        XCTAssertNil(ramadan(at: eveMaghrib.addingTimeInterval(-60), s))
        XCTAssertEqual(ramadan(at: eveMaghrib.addingTimeInterval(60), s),
                       .suhoorEnds(time(.fajr, on: firstDay, settings: s)))
    }

    func testIftarCountdownDuringTheDay() {
        let s = settings()
        XCTAssertEqual(ramadan(at: firstDay.addingTimeInterval(12 * 3600), s),
                       .iftar(time(.maghrib, on: firstDay, settings: s)))
    }

    func testEndsAtMaghribOnTheLastDay() {
        let s = settings()
        let lastMaghrib = time(.maghrib, on: lastDay, settings: s)
        XCTAssertEqual(ramadan(at: lastMaghrib.addingTimeInterval(-60), s), .iftar(lastMaghrib))
        XCTAssertNil(ramadan(at: lastMaghrib.addingTimeInterval(60), s))
    }

    func testHijriCorrectionShiftsTheWindow() {
        let eve = day(firstDay, -1)
        let later = settings(hijri: -1)   // month starts one day later locally
        XCTAssertNil(ramadan(at: time(.maghrib, on: eve, settings: later).addingTimeInterval(60), later))
        XCTAssertNotNil(ramadan(at: time(.maghrib, on: firstDay, settings: later).addingTimeInterval(60), later))

        let earlier = settings(hijri: 1)  // month starts one day earlier locally
        XCTAssertNotNil(ramadan(at: time(.maghrib, on: day(eve, -1), settings: earlier).addingTimeInterval(60), earlier))

        let noon = firstDay.addingTimeInterval(12 * 3600)
        let plain = PrayerSnapshot(date: noon, location: Fixtures.munich, settings: settings())!.hijriDate
        let shifted = PrayerSnapshot(date: noon, location: Fixtures.munich, settings: earlier)!.hijriDate
        XCTAssertNotEqual(plain, shifted)
        XCTAssertEqual(HijriDate.components(for: noon, timeZone: tz, adjustmentDays: 1).day, 2)
    }

    func testModeOnAndOff() {
        let rajabNoon = day(firstDay, -60).addingTimeInterval(12 * 3600)
        XCTAssertNotNil(ramadan(at: rajabNoon, settings(.on)))
        XCTAssertNil(ramadan(at: firstDay.addingTimeInterval(12 * 3600), settings(.off)))
    }

    func testSnapshotRamadanUsesAdjustedTimes() {
        var s = settings(.on)
        let plainMaghrib = time(.maghrib, on: firstDay, settings: s)
        s.adjustments = [.maghrib: 5]
        XCTAssertEqual(ramadan(at: firstDay.addingTimeInterval(12 * 3600), s), .iftar(plainMaghrib.addingTimeInterval(300)))
    }
}
