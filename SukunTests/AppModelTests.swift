import XCTest
@testable import Sukun
@testable import SukunKit

@MainActor
final class AppModelTests: XCTestCase {
    private func makeModel() -> (AppModel, SharedStore) {
        let defaults = UserDefaults(suiteName: "sukun.app.tests.\(UUID().uuidString)")!
        let store = SharedStore(defaults: defaults)
        return (AppModel(store: store), store)
    }

    func testManualLocationIsPersistedToSharedStore() {
        let (model, store) = makeModel()
        XCTAssertNil(model.location)
        let berlin = StoredLocation(coordinate: Coordinate(latitude: 52.52, longitude: 13.405),
                                    name: "Berlin", countryCode: "DE", timeZoneIdentifier: "Europe/Berlin", source: .manual)
        model.useManualLocation(berlin)
        XCTAssertEqual(model.location, berlin)
        XCTAssertEqual(store.effectiveLocation, berlin)
        XCTAssertNotNil(model.snapshot(at: Date()))
    }

    func testReminderStaysOffWhenPermissionDenied() async {
        let defaults = UserDefaults(suiteName: "sukun.app.tests.\(UUID().uuidString)")!
        let denied = AppModel(store: SharedStore(defaults: defaults), requestAuthorization: { false })
        await denied.setEarlyReminder(15)
        await denied.setJumuahReminder(.defaultReminder)
        await denied.setSuhoorReminder(30)
        XCTAssertNil(denied.settings.earlyReminderMinutes)
        XCTAssertNil(denied.settings.jumuahReminder)
        XCTAssertNil(denied.settings.suhoorReminderMinutes)

        let allowed = AppModel(store: SharedStore(defaults: defaults), requestAuthorization: { true })
        await allowed.setEarlyReminder(15)
        await allowed.setJumuahReminder(.fixedTime(hour: 12, minute: 45))
        await allowed.setSuhoorReminder(30)
        XCTAssertEqual(allowed.settings.earlyReminderMinutes, 15)
        XCTAssertEqual(allowed.settings.jumuahReminder, .fixedTime(hour: 12, minute: 45))
        XCTAssertEqual(allowed.settings.suhoorReminderMinutes, 30)

        await allowed.setEarlyReminder(nil)
        XCTAssertNil(allowed.settings.earlyReminderMinutes, "turning off never needs permission")
    }

    func testDesignPreviewMovesNowToTheChosenPrayer() throws {
        let (model, _) = makeModel()
        let munich = StoredLocation(coordinate: Coordinate(latitude: 48.1351, longitude: 11.5820),
                                    name: "München", countryCode: "DE", timeZoneIdentifier: "Europe/Berlin", source: .manual)
        model.useManualLocation(munich)
        let realNow = Fixtures.date(2026, 12, 15, 22, 0, tz: "Europe/Berlin")
        let asr = try XCTUnwrap(model.snapshot(at: realNow)?.today.time(for: .asr))

        model.setDesignPreview(.asr, now: realNow)
        XCTAssertEqual(model.now(realNow), asr.addingTimeInterval(600))
        XCTAssertEqual(model.snapshot(at: model.now(realNow))?.current?.kind, .asr)
        XCTAssertEqual(model.realDate(asr), asr.addingTimeInterval(realNow.timeIntervalSince(asr) - 600),
                       "timers count from the real clock, so virtual dates map back")

        model.setDesignPreview(nil, now: realNow)
        XCTAssertEqual(model.now(realNow), realNow)
    }

    func testSettingsBindingWritesThrough() {
        let (model, store) = makeModel()
        model.binding(\.clockFormat).wrappedValue = .twentyFourHour
        XCTAssertEqual(store.settings.clockFormat, .twentyFourHour)
    }

    func testFajrSheetChoices() async {
        let defaults = UserDefaults(suiteName: "sukun.fajr.tests.\(UUID().uuidString)")!
        let model = AppModel(store: SharedStore(defaults: defaults), requestAuthorization: { true })
        XCTAssertEqual(model.fajrReminder, .off)
        await model.setFajrReminder(.notification)
        XCTAssertEqual(model.fajrReminder, .notification)
        XCTAssertTrue(model.settings.notificationsEnabled.contains(.fajr))
        await model.setFajrReminder(.off)
        XCTAssertEqual(model.fajrReminder, .off)
        XCTAssertFalse(model.settings.notificationsEnabled.contains(.fajr))
    }

    func testAlarmChoiceStaysOffWhenAlarmsAreNotAllowed() async {
        // The simulator never grants AlarmKit: choosing the alarm must not leave a silent "Alarm" checked.
        let defaults = UserDefaults(suiteName: "sukun.fajr.tests.\(UUID().uuidString)")!
        let model = AppModel(store: SharedStore(defaults: defaults), requestAuthorization: { true })
        await model.setFajrReminder(.notification)
        let allowed = await model.setFajrReminder(.alarm(minutes: 20))
        if !allowed {
            XCTAssertEqual(model.fajrReminder, .notification)
            XCTAssertNil(model.settings.fajrAlarmMinutesBefore)
        }
    }
}
