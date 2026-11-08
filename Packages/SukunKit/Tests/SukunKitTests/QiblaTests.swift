import XCTest
@testable import SukunKit

final class QiblaTests: XCTestCase {
    func testMunichBearingAndDistance() {
        let c = Fixtures.munich.coordinate
        XCTAssertEqual(QiblaCalculator.bearing(from: c), 129.79, accuracy: 0.1)
        XCTAssertEqual(QiblaCalculator.distanceKilometers(from: c), 3890, accuracy: 10)
        XCTAssertEqual(CompassPoint(degrees: QiblaCalculator.bearing(from: c)), .southEast)
    }

    func testOtherReferenceCities() {
        XCTAssertEqual(QiblaCalculator.bearing(from: Coordinate(latitude: 52.52, longitude: 13.405)), 136.68, accuracy: 0.1)
        XCTAssertEqual(QiblaCalculator.bearing(from: Coordinate(latitude: 40.7128, longitude: -74.0060)), 58.48, accuracy: 0.1)
        XCTAssertEqual(QiblaCalculator.bearing(from: Coordinate(latitude: -6.2088, longitude: 106.8456)), 295.15, accuracy: 0.1)
        XCTAssertEqual(QiblaCalculator.distanceKilometers(from: Coordinate(latitude: 40.7128, longitude: -74.0060)), 10306, accuracy: 20)
    }

    func testMeccaIsAtTheKaaba() {
        XCTAssertLessThan(QiblaCalculator.distanceKilometers(from: Fixtures.mecca.coordinate), 1)
    }

    func testBearingAlwaysInRange() {
        for lat in stride(from: -80.0, through: 80, by: 20) {
            for lon in stride(from: -170.0, through: 170, by: 34) {
                let b = QiblaCalculator.bearing(from: Coordinate(latitude: lat, longitude: lon))
                XCTAssert((0..<360).contains(b), "\(lat),\(lon) -> \(b)")
            }
        }
    }

    func testAngleHelpers() {
        XCTAssertEqual(CompassAngle.normalized(-10), 350)
        XCTAssertEqual(CompassAngle.normalized(725), 5)
        XCTAssertEqual(CompassAngle.delta(from: 350, to: 10), 20)
        XCTAssertEqual(CompassAngle.delta(from: 10, to: 350), -20)
        XCTAssertEqual(CompassPoint(degrees: 359), .north)
        XCTAssertEqual(CompassPoint(degrees: 23), .northEast)
        XCTAssertEqual(CompassPoint(degrees: 270), .west)
    }
}
