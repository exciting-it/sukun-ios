import XCTest
@testable import SukunKit

final class SettingsAndFormattingTests: XCTestCase {
    func testSettingsRoundTripAndTolerantDecoding() throws {
        var s = SukunSettings()
        s.method = .turkey
        s.notificationsEnabled = [.fajr, .isha]
        s.manualLocation = Fixtures.munich
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(SukunSettings.self, from: data), s)

        let legacy = Data(#"{"method":"unknownMethod","clockFormat":"twentyFourHour","notificationsEnabled":["fajr","bogus"]}"#.utf8)
        let decoded = try JSONDecoder().decode(SukunSettings.self, from: legacy)
        XCTAssertEqual(decoded.method, .automatic)
        XCTAssertEqual(decoded.clockFormat, .twentyFourHour)
        XCTAssertEqual(decoded.notificationsEnabled, [.fajr])
    }

    func testSharedStoreEffectiveLocation() {
        let defaults = UserDefaults(suiteName: "sukun.tests.\(UUID().uuidString)")!
        let store = SharedStore(defaults: defaults)
        XCTAssertNil(store.effectiveLocation)
        var gps = Fixtures.mecca
        gps.source = .gps
        store.gpsLocation = gps
        XCTAssertEqual(store.effectiveLocation, gps)

        var s = store.settings
        s.manualLocation = Fixtures.munich
        s.useManualLocation = true
        store.settings = s
        XCTAssertEqual(store.effectiveLocation, Fixtures.munich)
    }

    func testTimeFormatting() {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        let date = Fixtures.date(2026, 12, 15, 18, 8, tz: "Europe/Berlin")
        let f24 = PrayerTimeFormatter(clockFormat: .twentyFourHour, timeZone: tz, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(f24.string(from: date), "18:08")
        XCTAssertNil(f24.periodSymbol(for: date))
        let f12 = PrayerTimeFormatter(clockFormat: .twelveHour, timeZone: tz, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(f12.numerals(from: date), "6:08")
        XCTAssertEqual(f12.periodSymbol(for: date), "PM")
        let system = PrayerTimeFormatter(clockFormat: .system, timeZone: tz, locale: Locale(identifier: "de_DE"))
        XCTAssertFalse(system.uses12Hour)
    }

    func testHijriDate() {
        let date = Fixtures.date(2026, 12, 15, 12, tz: "Asia/Riyadh")
        let c = HijriDate.components(for: date, timeZone: TimeZone(identifier: "Asia/Riyadh")!)
        XCTAssertEqual(c.year, 1448)
        XCTAssertEqual(c.month, 7) // Rajab
        XCTAssert((5...7).contains(c.day ?? 0), "day \(String(describing: c.day))")
    }
}
