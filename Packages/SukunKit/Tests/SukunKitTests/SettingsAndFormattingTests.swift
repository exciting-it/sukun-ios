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

    func testNewSettingsDefaultFromOldJSON() throws {
        // Exactly what 1.0 builds before these features wrote.
        let old = Data(#"{"method":"automatic","madhab":"automatic","highLatitude":"automatic","clockFormat":"system","useManualLocation":false,"notificationsEnabled":["isha"],"showsPattern":true,"qiblaHaptics":true}"#.utf8)
        let s = try JSONDecoder().decode(SukunSettings.self, from: old)
        XCTAssertEqual(s.adjustments, [:])
        XCTAssertNil(s.earlyReminderMinutes)
        XCTAssertNil(s.jumuahReminder)
        XCTAssertEqual(s.ramadanMode, .automatic)
        XCTAssertNil(s.suhoorReminderMinutes)
        XCTAssertEqual(s.hijriAdjustmentDays, 0)
        XCTAssertFalse(s.hasAdjustments)
        XCTAssertEqual(s.notificationsEnabled, [.isha])
    }

    func testNewSettingsRoundTrip() throws {
        var s = SukunSettings()
        s.adjustments = [.isha: 5, .fajr: -2, .sunrise: 3]
        s.earlyReminderMinutes = 15
        s.jumuahReminder = .fixedTime(hour: 12, minute: 45)
        s.ramadanMode = .on
        s.suhoorReminderMinutes = 30
        s.hijriAdjustmentDays = -1
        let decoded = try JSONDecoder().decode(SukunSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.adjustment(for: .isha), 5)
        XCTAssertEqual(decoded.adjustment(for: .dhuhr), 0)
        XCTAssertTrue(decoded.hasAdjustments)

        s.jumuahReminder = .beforeDhuhr(minutes: 60)
        XCTAssertEqual(try JSONDecoder().decode(SukunSettings.self, from: JSONEncoder().encode(s)).jumuahReminder, .beforeDhuhr(minutes: 60))
    }

    func testOutOfRangeValuesAreClamped() throws {
        let json = Data(#"{"adjustments":{"isha":90,"fajr":-45,"bogus":5,"dhuhr":0},"hijriAdjustmentDays":5,"earlyReminderMinutes":7,"suhoorReminderMinutes":0,"jumuahReminder":{"beforeDhuhr":{"minutes":17}}}"#.utf8)
        let s = try JSONDecoder().decode(SukunSettings.self, from: json)
        XCTAssertEqual(s.adjustments, [.isha: 30, .fajr: -30])
        XCTAssertEqual(s.hijriAdjustmentDays, 2)
        XCTAssertNil(s.earlyReminderMinutes)
        XCTAssertNil(s.suhoorReminderMinutes)
        XCTAssertEqual(s.jumuahReminder, JumuahReminder.defaultReminder)

        let badTime = Data(#"{"jumuahReminder":{"fixedTime":{"hour":25,"minute":0}}}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SukunSettings.self, from: badTime).jumuahReminder)
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

    func testWidthSamplesCoverTheWidestTimes() {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        let f12 = PrayerTimeFormatter(clockFormat: .twelveHour, timeZone: tz, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(Set(f12.widthSamples), ["12:58 AM", "12:58 PM", "8:58 PM"])
        let f24 = PrayerTimeFormatter(clockFormat: .twentyFourHour, timeZone: tz, locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(f24.widthSamples.contains("20:58"))
    }

    func testCivilDateIsGregorianEvenWhereTheDefaultCalendarIsIslamic() {
        // ar_SA defaults to the Umm al-Qura calendar; the second date line must stay Gregorian.
        let date = Fixtures.date(2026, 11, 9, 12, tz: "Asia/Riyadh")
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let arabic = CivilDate.string(for: date, timeZone: tz, locale: Locale(identifier: "ar_SA"))
        XCTAssertTrue(arabic.contains("نوفمبر"), arabic)
        XCTAssertFalse(arabic.contains("جمادى"), arabic)
        let german = CivilDate.string(for: date, timeZone: tz, locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(german, "Montag, 9. November")
    }

    func testVoiceControlNamesIncludeVisibleNameDescriptionAndSpellings() {
        let isha = PrayerKind.isha.voiceControlNames
        XCTAssertEqual(isha.first, PrayerKind.isha.localizedName, "the visible name comes first")
        XCTAssertTrue(isha.contains("Night prayer"))
        XCTAssertTrue(isha.contains("Aisha"), "what English dictation often hears for Isha")
        XCTAssertTrue(PrayerKind.dhuhr.voiceControlNames.contains("Zuhr"))
        XCTAssertTrue(PrayerKind.maghrib.voiceControlNames.contains("Maghreb"))
        XCTAssertEqual(Set(isha).count, isha.count, "no duplicates")
        XCTAssertTrue(VoiceControlNames.qibla.contains("Compass"))
    }

    func testHijriDate() {
        let date = Fixtures.date(2026, 12, 15, 12, tz: "Asia/Riyadh")
        let c = HijriDate.components(for: date, timeZone: TimeZone(identifier: "Asia/Riyadh")!)
        XCTAssertEqual(c.year, 1448)
        XCTAssertEqual(c.month, 7) // Rajab
        XCTAssert((5...7).contains(c.day ?? 0), "day \(String(describing: c.day))")
    }
}
