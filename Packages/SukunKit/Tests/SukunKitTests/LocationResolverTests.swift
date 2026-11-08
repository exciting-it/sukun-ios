#if canImport(CoreLocation) && !os(Linux)
import CoreLocation
import XCTest
@testable import SukunKit

final class LocationResolverTests: XCTestCase {
    /// A stale cached fix (e.g. CLLocationManager.location after a timeout) must keep its own age,
    /// otherwise it counts as fresh and blocks the next real location refresh.
    func testNearbyCachedFixKeepsItsOwnTimestamp() async {
        let previous = Fixtures.munich
        let fixTime = Date().addingTimeInterval(-3 * 3600)
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 48.1360, longitude: 11.5830),
            altitude: 0, horizontalAccuracy: 50, verticalAccuracy: -1, timestamp: fixTime
        )
        let resolved = await LocationResolver.storedLocation(for: fix, previous: previous)
        XCTAssertEqual(resolved.updatedAt, fixTime)
        XCTAssertEqual(resolved.name, previous.name, "nearby fix reuses the stored place name")
    }

    func testFutureTimestampIsClampedToNow() async {
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 48.1360, longitude: 11.5830),
            altitude: 0, horizontalAccuracy: 50, verticalAccuracy: -1, timestamp: Date().addingTimeInterval(3600)
        )
        let resolved = await LocationResolver.storedLocation(for: fix, previous: Fixtures.munich)
        XCTAssertLessThanOrEqual(resolved.updatedAt, Date())
    }
}
#endif
