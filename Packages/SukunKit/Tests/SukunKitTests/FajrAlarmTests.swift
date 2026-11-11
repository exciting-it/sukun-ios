import XCTest
@testable import SukunKit

final class FajrAlarmTests: XCTestCase {
    private let tz = "Europe/Berlin"
    private var now: Date { Fixtures.date(2026, 12, 15, 12, tz: tz) }

    private func settings(alarm: Int?, fajrNotification: Bool = true, early: Int? = nil) -> SukunSettings {
        var s = Fixtures.settings(method: .muslimWorldLeague)
        s.fajrAlarmMinutesBefore = alarm
        s.notificationsEnabled = fajrNotification ? [.fajr, .isha] : [.isha]
        s.earlyReminderMinutes = early
        return s
    }

    func testSettingIsOffByDefaultAndClamped() throws {
        XCTAssertNil(SukunSettings().fajrAlarmMinutesBefore)
        var s = SukunSettings()
        s.fajrAlarmMinutesBefore = 20
        XCTAssertEqual(try JSONDecoder().decode(SukunSettings.self, from: JSONEncoder().encode(s)).fajrAlarmMinutesBefore, 20)
        let bad = Data(#"{"fajrAlarmMinutesBefore":17}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SukunSettings.self, from: bad).fajrAlarmMinutesBefore)
        XCTAssertEqual(ReminderChoices.fajrAlarm, [0, 10, 20, 30])
    }

    func testOneAlarmPerDayBeforeFajrForAWeek() throws {
        let plan = FajrAlarmPlan.make(settings: settings(alarm: 20), location: Fixtures.munich, now: now)
        XCTAssertEqual(plan.count, 7)
        let calculator = PrayerCalculator(location: Fixtures.munich, settings: settings(alarm: 20))
        let tomorrow = try XCTUnwrap(calculator.schedule(for: now.addingTimeInterval(86_400))?.time(for: .fajr))
        XCTAssertEqual(plan.first?.fajr, tomorrow, "today's Fajr is over at noon")
        XCTAssertEqual(plan.first?.date, tomorrow.addingTimeInterval(-20 * 60))
        XCTAssertEqual(plan.map(\.date), plan.map(\.date).sorted())
        XCTAssertTrue(plan.allSatisfy { $0.date > now })
    }

    func testIDsAreStablePerFajrSoRescheduleIsIdempotent() {
        let a = FajrAlarmPlan.make(settings: settings(alarm: 0), location: Fixtures.munich, now: now)
        let b = FajrAlarmPlan.make(settings: settings(alarm: 0), location: Fixtures.munich, now: now.addingTimeInterval(60))
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        let other = FajrAlarmPlan.make(settings: settings(alarm: 10), location: Fixtures.munich, now: now)
        XCTAssertNotEqual(a.first?.id, other.first?.id, "a different time is a different alarm")
        XCTAssertEqual(Set(a.map(\.id)).count, a.count)
    }

    func testIDsNeverCollideAcrossAYear() {
        let start = Fixtures.date(2026, 1, 1, 5, tz: tz)
        var ids = Set<UUID>()
        for day in 0..<366 {
            for minutes in ReminderChoices.fajrAlarm {
                ids.insert(FajrAlarmPlan.stableID(fajr: start.addingTimeInterval(Double(day) * 86_400 + Double(day % 7) * 60),
                                                  minutes: minutes))
            }
        }
        XCTAssertEqual(ids.count, 366 * ReminderChoices.fajrAlarm.count)
    }

    func testNoAlarmsWhenOff() {
        XCTAssertEqual(FajrAlarmPlan.make(settings: settings(alarm: nil), location: Fixtures.munich, now: now), [])
    }

    func testAlarmReplacesTheFajrNotificationAndItsEarlyReminder() {
        let s = settings(alarm: 20, early: 15)
        let withAlarm = NotificationPlan.make(settings: s, location: Fixtures.munich, now: now, fajrAlarmActive: true)
        let fajr: (PlannedNotification) -> Bool = {
            switch $0.content {
            case .prayer(let slot, _), .early(let slot, _): slot.kind == .fajr
            default: false
            }
        }
        XCTAssertFalse(withAlarm.contains(where: fajr))
        XCTAssertTrue(withAlarm.contains { if case .prayer(let slot, _) = $0.content { slot.kind == .isha } else { false } })
        let withoutAlarm = NotificationPlan.make(settings: s, location: Fixtures.munich, now: now, fajrAlarmActive: false)
        XCTAssertTrue(withoutAlarm.contains(where: fajr), "no AlarmKit (older iOS, or not allowed): keep the notification")
    }
}
