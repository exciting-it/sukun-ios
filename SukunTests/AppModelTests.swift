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

    func testSettingsBindingWritesThrough() {
        let (model, store) = makeModel()
        model.binding(\.clockFormat).wrappedValue = .twentyFourHour
        XCTAssertEqual(store.settings.clockFormat, .twentyFourHour)
    }
}
