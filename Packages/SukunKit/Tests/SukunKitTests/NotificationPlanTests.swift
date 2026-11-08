import XCTest
@testable import SukunKit

final class NotificationPlanTests: XCTestCase {
    private func settings(_ enabled: Set<PrayerKind>, early: Int? = nil, jumuah: JumuahReminder? = nil,
                          ramadan: RamadanMode = .automatic, suhoor: Int? = nil) -> SukunSettings {
        var s = Fixtures.settings(method: .muslimWorldLeague)
        s.notificationsEnabled = enabled
        s.earlyReminderMinutes = early
        s.jumuahReminder = jumuah
        s.ramadanMode = ramadan
        s.suhoorReminderMinutes = suhoor
        return s
    }

    private func plan(_ s: SukunSettings, _ location: StoredLocation = Fixtures.munich, now: Date, days: Int = 7) -> [PlannedNotification] {
        NotificationPlan.make(settings: s, location: location, now: now, days: days)
    }

    private func calendar(_ tz: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal
    }

    private func prayerSlots(_ items: [PlannedNotification]) -> [PrayerSlot] {
        items.compactMap { if case .prayer(let slot, _) = $0.content { slot } else { nil } }
    }

    private func earlySlots(_ items: [PlannedNotification]) -> [PrayerSlot] {
        items.compactMap { if case .early(let slot, _) = $0.content { slot } else { nil } }
    }

    func testEarlyReminderFifteenMinutesBefore() throws {
        let now = Fixtures.date(2026, 12, 15, 10, 0, tz: "Europe/Berlin")
        let items = plan(settings([.isha], early: 15), now: now)
        let early = try XCTUnwrap(items.first { if case .early = $0.content { true } else { false } })
        guard case .early(let slot, let minutes) = early.content else { return XCTFail() }
        XCTAssertEqual(slot.kind, .isha)
        XCTAssertEqual(minutes, 15)
        XCTAssertEqual(early.fireDate, slot.date.addingTimeInterval(-900))
        XCTAssertTrue(prayerSlots(items).contains(slot))
        XCTAssertEqual(items.map(\.fireDate), items.map(\.fireDate).sorted())
        XCTAssertTrue(items.allSatisfy { $0.id.hasPrefix("sukun.") })
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }

    func testNeverMoreThanSixty() {
        let now = Fixtures.date(2026, 12, 15, 0, 5, tz: "Europe/Berlin")
        let items = plan(settings(Set(PrayerKind.obligatory), early: 5, jumuah: .defaultReminder, ramadan: .on, suhoor: 30), now: now)
        XCTAssertLessThanOrEqual(items.count, NotificationPlan.budget)
        XCTAssertGreaterThan(items.count, 50)
        var extras: [PrayerSlot: Int] = [:]
        for item in items {
            switch item.content {
            case .early(let slot, _): extras[slot, default: 0] += 1
            case .jumuah(let dhuhr): extras[dhuhr, default: 0] += 1
            case .suhoor(let fajr, _): extras[fajr, default: 0] += 1
            case .prayer: break
            }
        }
        XCTAssertTrue(extras.values.allSatisfy { $0 == 1 }, "at most one extra notification per prayer")
    }

    func testJumuahOnlyOnFridaysInLocationTimeZone() throws {
        // Thursday 12 Nov 2026, 23:30 in Berlin is already Friday 01:30 in Mecca.
        let now = Fixtures.date(2026, 11, 12, 23, 30, tz: "Europe/Berlin")
        let items = plan(settings([], jumuah: .beforeDhuhr(minutes: 45)), Fixtures.mecca, now: now)
        let riyadh = calendar("Asia/Riyadh")
        let jumuah = items.filter { if case .jumuah = $0.content { true } else { false } }
        XCTAssertEqual(jumuah.count, 1)
        let first = try XCTUnwrap(jumuah.first)
        XCTAssertEqual(riyadh.component(.weekday, from: first.fireDate), 6)
        XCTAssertEqual(riyadh.component(.day, from: first.fireDate), 13)
        guard case .jumuah(let dhuhr) = first.content else { return XCTFail() }
        XCTAssertEqual(first.fireDate, dhuhr.date.addingTimeInterval(-45 * 60))
        XCTAssertTrue(prayerSlots(items).isEmpty, "Dhuhr toggle is off; Jumu'ah stands alone")
    }

    func testJumuahFixedTimeSurvivesDST() {
        // DST ends Sunday 25 Oct 2026 in Europe/Berlin.
        let now = Fixtures.date(2026, 10, 22, 8, 0, tz: "Europe/Berlin")
        let items = plan(settings([], jumuah: .fixedTime(hour: 12, minute: 45)), now: now, days: 9)
        let berlin = calendar("Europe/Berlin")
        let times = items.map { berlin.dateComponents([.day, .hour, .minute], from: $0.fireDate) }
        XCTAssertEqual(times.map(\.day), [23, 30])
        XCTAssertTrue(times.allSatisfy { $0.hour == 12 && $0.minute == 45 })
    }

    func testJumuahReplacesDhuhrEarlyReminder() {
        let now = Fixtures.date(2026, 11, 12, 6, 0, tz: "Europe/Berlin") // Thursday
        let items = plan(settings([.dhuhr], early: 10, jumuah: .beforeDhuhr(minutes: 45)), now: now)
        let berlin = calendar("Europe/Berlin")
        let earlyDays = earlySlots(items).map { berlin.component(.weekday, from: $0.date) }
        XCTAssertFalse(earlyDays.contains(6), "no early Dhuhr reminder on Friday")
        XCTAssertTrue(earlyDays.contains(5), "Thursday keeps its early reminder")
        XCTAssertEqual(items.filter { if case .jumuah = $0.content { true } else { false } }.count, 1)
    }

    func testSuhoorReplacesFajrEarlyReminder() {
        let now = Fixtures.date(2026, 12, 15, 0, 5, tz: "Europe/Berlin")
        let items = plan(settings([.fajr], early: 10, ramadan: .on, suhoor: 30), now: now)
        XCTAssertTrue(earlySlots(items).isEmpty)
        let suhoor = items.compactMap { item -> (Date, PrayerSlot)? in
            if case .suhoor(let fajr, let minutes) = item.content, minutes == 30 { (item.fireDate, fajr) } else { nil }
        }
        XCTAssertFalse(suhoor.isEmpty)
        XCTAssertTrue(suhoor.allSatisfy { $0.0 == $0.1.date.addingTimeInterval(-1800) })
    }

    func testLateReminderIsSkippedButPrayerKept() {
        let s = settings([.maghrib], early: 15)
        let day = Fixtures.date(2026, 12, 15, 12, 0, tz: "Europe/Berlin")
        let maghrib = PrayerCalculator(location: Fixtures.munich, settings: s).schedule(for: day)!.time(for: .maghrib)!
        let items = plan(s, now: maghrib.addingTimeInterval(-600))
        XCTAssertTrue(prayerSlots(items).contains { $0.date == maghrib })
        XCTAssertFalse(earlySlots(items).contains { $0.date == maghrib })
        XCTAssertFalse(earlySlots(items).isEmpty, "the next days keep theirs")
    }

    func testRamadanVariantsAndSuhoorOnlyInsideWindow() {
        let tz = "Europe/Berlin"
        let (first, _) = Fixtures.ramadan1448(tz: tz)
        let berlin = calendar(tz)
        let eve = berlin.date(byAdding: .day, value: -1, to: first)!
        let items = plan(settings([.fajr, .maghrib], suhoor: 30), now: eve.addingTimeInterval(30 * 60), days: 2)
        func variant(_ kind: PrayerKind, on day: Date) -> RamadanVariant?? {
            items.lazy.compactMap { item -> RamadanVariant?? in
                if case .prayer(let slot, let v) = item.content, slot.kind == kind, berlin.isDate(slot.date, inSameDayAs: day) { v } else { nil }
            }.first
        }
        XCTAssertEqual(variant(.fajr, on: eve), .some(nil))
        XCTAssertEqual(variant(.maghrib, on: eve), .some(nil))
        XCTAssertEqual(variant(.fajr, on: first), .some(.suhoorEnded))
        XCTAssertEqual(variant(.maghrib, on: first), .some(.iftar))
        let suhoorDays = items.compactMap { item -> Date? in
            if case .suhoor(let fajr, _) = item.content { fajr.date } else { nil }
        }
        XCTAssertEqual(suhoorDays.count, 1)
        XCTAssertTrue(berlin.isDate(suhoorDays[0], inSameDayAs: first))
    }

    func testIshaAfterMidnightSurvivesARescheduleJustAfterMidnight() throws {
        // Munich, 21 June 2027, "middle of the night": Isha of the 20th falls after midnight (~00:12).
        var s = settings([.isha])
        s.highLatitude = .middleOfTheNight
        let calculator = PrayerCalculator(location: Fixtures.munich, settings: s)
        let isha = try XCTUnwrap(calculator.schedule(for: Fixtures.date(2027, 6, 20, 12, 0, tz: "Europe/Berlin"))?.time(for: .isha))
        let midnight = Fixtures.date(2027, 6, 21, 0, 0, tz: "Europe/Berlin")
        try XCTSkipUnless(isha > midnight, "fixture assumption: Isha after midnight")
        let items = plan(s, now: midnight.addingTimeInterval(60))
        XCTAssertTrue(prayerSlots(items).contains { $0.date == isha }, "yesterday's Isha after midnight must stay scheduled")
    }

    func testSuhoorStandsAloneWithoutPrayerToggles() {
        let items = plan(settings([], ramadan: .on, suhoor: 30), now: Fixtures.date(2026, 12, 15, 10, 0, tz: "Europe/Berlin"))
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { if case .suhoor = $0.content { true } else { false } })
    }

    func testEmptyWhenNothingEnabled() {
        XCTAssertTrue(plan(settings([]), now: Fixtures.date(2026, 12, 15, 10, 0, tz: "Europe/Berlin")).isEmpty)
    }
}
