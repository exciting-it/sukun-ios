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
}
