import XCTest
@testable import SukunKit

final class NotificationRefreshTests: XCTestCase {
    private let now = Fixtures.date(2026, 12, 15, 12, tz: "Europe/Berlin")
    private var settings: SukunSettings {
        var s = Fixtures.settings(method: .muslimWorldLeague)
        s.notificationsEnabled = [.fajr, .isha]
        return s
    }

    // MARK: Text (formerly app-only, now shared with the widget)

    func testTextsAreBuiltInTheKit() {
        let f = PrayerTimeFormatter(clockFormat: .twentyFourHour, timeZone: TimeZone(identifier: "Europe/Berlin")!,
                                    locale: Locale(identifier: "en_US"))
        let slot = PrayerSlot(kind: .maghrib, date: now)
        func text(_ c: PlannedNotification.Content) -> (title: String, body: String) {
            NotificationText.content(for: PlannedNotification(id: "x", fireDate: now, content: c), formatter: f)
        }
        XCTAssertEqual(text(.prayer(slot, ramadan: nil)).body, "It’s time for Maghrib · 12:00")
        XCTAssertEqual(text(.prayer(slot, ramadan: .iftar)).body, "Time for Iftar · 12:00")
        XCTAssertEqual(text(.prayer(slot, ramadan: .suhoorEnded)).body, "Suhoor has ended · 12:00")
        XCTAssertEqual(text(.early(slot, minutes: 15)).body, "Maghrib in 15 min · 12:00")
        XCTAssertEqual(text(.jumuah(dhuhr: slot)).title, "Jumu'ah")
        XCTAssertEqual(text(.jumuah(dhuhr: slot)).body, "Today · Dhuhr 12:00")
        XCTAssertEqual(text(.suhoor(fajr: slot, minutes: 30)).body, "Suhoor ends in 30 min · Fajr 12:00")
        XCTAssertEqual(text(.openApp).title, "Sukun")
        XCTAssertEqual(text(.openApp).body, "Open Sukun to keep your prayer reminders coming.")
    }

    // MARK: Last-resort reminder

    func testPlanEndsWithAQuietOpenAppReminder() {
        let plan = NotificationPlan.make(settings: settings, location: Fixtures.munich, now: now)
        XCTAssertLessThanOrEqual(plan.count, NotificationPlan.budget)
        XCTAssertEqual(plan.last?.content, .openApp)
        XCTAssertEqual(plan.filter { $0.content == .openApp }.count, 1)
        let lastReal = plan.dropLast().last!
        XCTAssertEqual(plan.last!.fireDate, lastReal.fireDate.addingTimeInterval(3600))
        XCTAssertEqual(plan.last!.id, "sukun.openApp")
    }

    func testNoOpenAppReminderWithoutReminders() {
        XCTAssertEqual(NotificationPlan.make(settings: SukunSettings(), location: Fixtures.munich, now: now), [])
    }

    // MARK: When the widget reschedules

    private func stamp(_ location: StoredLocation = Fixtures.munich, settings s: SukunSettings? = nil) -> NotificationStamp {
        NotificationStamp(location: location, settings: s ?? settings,
                          plan: NotificationPlan.make(settings: s ?? settings, location: location, now: now))
    }

    func testNoRescheduleWhenNothingChanged() {
        XCTAssertFalse(stamp().needsReschedule(location: Fixtures.munich, settings: settings, now: now))
        XCTAssertFalse(stamp().needsReschedule(location: Fixtures.munich, settings: settings, now: now + 3 * 86_400))
    }

    func testRescheduleAfterTravel() {
        var dubai = Fixtures.munich
        dubai.coordinate = Coordinate(latitude: 25.2048, longitude: 55.2708)
        dubai.timeZoneIdentifier = "Asia/Dubai"
        XCTAssertTrue(stamp().needsReschedule(location: dubai, settings: settings, now: now))

        var renamed = Fixtures.munich
        renamed.name = nil
        XCTAssertTrue(stamp(renamed).needsReschedule(location: Fixtures.munich, settings: settings, now: now),
                      "a place name arriving later updates the subtitle")
    }

    func testRescheduleWhenSettingsChangeOrPlanRunsOut() {
        var changed = settings
        changed.notificationsEnabled.insert(.maghrib)
        XCTAssertTrue(stamp().needsReschedule(location: Fixtures.munich, settings: changed, now: now))
        XCTAssertTrue(stamp().needsReschedule(location: Fixtures.munich, settings: settings, now: now + 5 * 86_400),
                      "less than 3 days of reminders left")
        XCTAssertTrue(NotificationStamp?.none.needsReschedule(location: Fixtures.munich, settings: settings, now: now))
    }

    func testStampRoundTripsThroughTheSharedStore() {
        let store = SharedStore(defaults: UserDefaults(suiteName: "sukun.stamp.\(UUID().uuidString)")!)
        XCTAssertNil(store.notificationStamp)
        store.notificationStamp = stamp()
        XCTAssertEqual(store.notificationStamp, stamp())
    }

    // MARK: Place lookup after landing offline

    func testIncompletePlaceIsLookedUpAgainNearby() {
        let near = Coordinate(latitude: 48.1360, longitude: 11.5830)
        XCTAssertTrue(LocationResolver.canReuse(Fixtures.munich, for: near))
        var noName = Fixtures.munich
        noName.name = nil
        XCTAssertFalse(LocationResolver.canReuse(noName, for: near))
        var noCountry = Fixtures.munich
        noCountry.countryCode = nil
        XCTAssertFalse(LocationResolver.canReuse(noCountry, for: near))
        XCTAssertFalse(LocationResolver.canReuse(Fixtures.munich, for: Coordinate(latitude: 25.2, longitude: 55.27)))
    }
}

extension Optional where Wrapped == NotificationStamp {
    func needsReschedule(location: StoredLocation, settings: SukunSettings, now: Date) -> Bool {
        NotificationStamp.needsReschedule(self, location: location, settings: settings, now: now)
    }
}
