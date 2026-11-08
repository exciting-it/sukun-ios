import XCTest
@testable import SukunKit

final class TimelineTests: XCTestCase {
    private let settings = Fixtures.settings(method: .muslimWorldLeague)

    func testTransitionsCoverEveryBoundaryFor48Hours() {
        let now = Fixtures.date(2026, 12, 15, 10, 0, tz: "Europe/Berlin")
        let dates = PrayerTimeline.transitionDates(from: now, hours: 48, location: Fixtures.munich, settings: settings)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        // 6 boundaries per day * 2 days + 2 midnights + now = 15 (±1 depending on where `now` falls)
        XCTAssert((13...16).contains(dates.count), "count \(dates.count)")
        XCTAssert(dates.contains(Fixtures.date(2026, 12, 16, 0, 0, tz: "Europe/Berlin")))
        XCTAssert(dates.allSatisfy { $0 < now.addingTimeInterval(48 * 3600) })
    }

    func testSnapshotAtDhuhrPointsToAsr() {
        let calculator = PrayerCalculator(location: Fixtures.munich, settings: settings)
        let dhuhr = calculator.schedule(for: Fixtures.date(2026, 12, 15, 12, tz: "Europe/Berlin"))!.time(for: .dhuhr)!
        let snapshot = PrayerSnapshot(date: dhuhr, location: Fixtures.munich, settings: settings)!
        XCTAssertEqual(snapshot.previous.kind, .dhuhr)
        XCTAssertEqual(snapshot.next.kind, .asr)
        XCTAssertEqual(snapshot.period, .midday)
        XCTAssertEqual(snapshot.progress, 0, accuracy: 0.001)
    }

    func testEverySnapshotHasFutureNextPrayer() {
        let now = Fixtures.date(2026, 10, 15, 21, 0, tz: "Europe/Berlin")
        let snapshots = PrayerTimeline.snapshots(from: now, location: Fixtures.munich, settings: settings)
        XCTAssertFalse(snapshots.isEmpty)
        for s in snapshots {
            XCTAssertGreaterThan(s.next.date, s.date)
            XCTAssertLessThanOrEqual(s.previous.date, s.date)
            XCTAssertTrue(s.next.kind.isObligatory)
        }
    }

    func testTimeZoneOfLocationIsUsedForDayBoundaries() {
        // 23:30 in Berlin is already the next day in Riyadh: Mecca's schedule must use Riyadh's civil day.
        let instant = Fixtures.date(2026, 12, 15, 23, 30, tz: "Europe/Berlin")
        let calculator = PrayerCalculator(location: Fixtures.mecca, settings: Fixtures.settings(method: .ummAlQura))
        let schedule = calculator.schedule(for: instant)!
        XCTAssertEqual(schedule.day, Fixtures.date(2026, 12, 16, tz: "Asia/Riyadh"))
    }

    private func snapshot(_ d: Int, _ h: Int, _ m: Int = 0) -> PrayerSnapshot {
        PrayerSnapshot(date: Fixtures.date(2026, 12, d, h, m, tz: "Europe/Berlin"), location: Fixtures.munich, settings: settings)!
    }

    func testCurrentPrayerIsTheRunningOne() {
        let s = snapshot(15, 15, 0) // Munich, 15 Dec: Asr ~13:57, Maghrib ~16:23
        XCTAssertEqual(s.current?.kind, .asr)
        XCTAssertEqual(s.upcoming.kind, .maghrib)
        XCTAssertEqual(s.featured, s.current)
        XCTAssertTrue(s.isCurrent(s.today.time(for: .asr).map { PrayerSlot(kind: .asr, date: $0) }!))
        XCTAssertTrue(s.isPast(s.today.slots.first { $0.kind == .dhuhr }!))
        XCTAssertFalse(s.isPast(s.today.slots.first { $0.kind == .asr }!))
        XCTAssertFalse(s.isPast(s.today.slots.first { $0.kind == .maghrib }!))
    }

    func testFajrEndsAtSunrise() {
        let duringFajr = snapshot(15, 7, 0) // Fajr ~6:00, sunrise ~8:00
        XCTAssertEqual(duringFajr.current?.kind, .fajr)
        XCTAssertEqual(duringFajr.upcoming.kind, .sunrise, "the hint tells when Fajr ends")
        XCTAssertEqual(duringFajr.next.kind, .dhuhr)
    }

    func testNoPrayerIsRunningBetweenSunriseAndDhuhr() {
        let s = snapshot(15, 10, 0)
        XCTAssertNil(s.current)
        XCTAssertEqual(s.upcoming.kind, .dhuhr)
        XCTAssertEqual(s.featured.kind, .dhuhr)
        XCTAssertFalse(s.today.slots.contains { s.isCurrent($0) })
        XCTAssertTrue(s.isPast(s.today.slots.first { $0.kind == .fajr }!))
    }

    func testIshaStaysCurrentAfterMidnightUntilFajr() {
        let evening = snapshot(15, 21, 0)
        XCTAssertEqual(evening.current?.kind, .isha)
        XCTAssertTrue(evening.today.slots.contains(evening.current!), "the evening still shows today's list")
        XCTAssertEqual(evening.upcoming.kind, .fajr)

        let afterMidnight = snapshot(16, 2, 0)
        XCTAssertEqual(afterMidnight.current?.kind, .isha)
        XCTAssertEqual(afterMidnight.current, evening.current, "it's yesterday's Isha")
        XCTAssertFalse(afterMidnight.today.slots.contains(afterMidnight.current!))
        XCTAssertEqual(afterMidnight.today.day, Fixtures.date(2026, 12, 16, tz: "Europe/Berlin"))
        XCTAssertEqual(afterMidnight.upcoming.kind, .fajr)
        XCTAssertFalse(afterMidnight.today.slots.contains { afterMidnight.isPast($0) })
    }

    func testEverySnapshotHasAFutureUpcomingBoundary() {
        let now = Fixtures.date(2026, 10, 15, 21, 0, tz: "Europe/Berlin")
        for s in PrayerTimeline.snapshots(from: now, location: Fixtures.munich, settings: settings) {
            XCTAssertGreaterThan(s.upcoming.date, s.date)
            XCTAssertLessThanOrEqual(s.upcoming.date, s.next.date)
            if let current = s.current { XCTAssertLessThanOrEqual(current.date, s.date) }
        }
    }
}
