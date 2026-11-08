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

    func testSettingsBindingWritesThrough() {
        let (model, store) = makeModel()
        model.binding(\.clockFormat).wrappedValue = .twentyFourHour
        XCTAssertEqual(store.settings.clockFormat, .twentyFourHour)
    }
}
