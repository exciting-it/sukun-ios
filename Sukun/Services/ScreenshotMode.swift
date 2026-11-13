#if DEBUG
import Foundation
import SukunKit

/// Debug-only launch arguments for App Store screenshots in the simulator:
/// `-SukunScreenshotCity london|berlin|berlin-ar|dubai` sets a manual location and a few reminders,
/// `-SukunDesignPreview asr` shows that time of day, `-SukunRamadan on` forces Ramadan mode,
/// `-SukunScreenshotDay 2027-02-20` previews another date, `-SukunPreviewMinutes 60` lands that many minutes after
/// the previewed prayer (default 10; e.g. `sunrise` + 60 shows Duha), `-SukunFakeAlarm 20` / `-SukunOpenFajrSheet YES` show a set Fajr alarm with its sheet, `-SukunFakeQiblaOffset 0` simulates a compass reading that many degrees off the Qibla.
@MainActor
enum ScreenshotMode {
    private static let defaults = UserDefaults.standard

    static var fakeQiblaOffset: Double? {
        defaults.string(forKey: "SukunFakeQiblaOffset").flatMap(Double.init)
    }

    static var isActive: Bool { defaults.string(forKey: "SukunScreenshotCity") != nil }

    static func apply(to model: AppModel) {
        guard let city = defaults.string(forKey: "SukunScreenshotCity"), let location = location(for: city) else { return }
        let ramadan = defaults.string(forKey: "SukunRamadan").flatMap(RamadanMode.init(rawValue:)) ?? .automatic
        model.update {
            $0.manualLocation = location
            $0.useManualLocation = true
            $0.notificationsEnabled = [.fajr, .maghrib, .isha]
            $0.ramadanMode = ramadan
            $0.suhoorReminderMinutes = ramadan == .on ? 30 : nil
        }
        let day = defaults.string(forKey: "SukunScreenshotDay").flatMap { try? Date("\($0)T12:00:00Z", strategy: .iso8601) }
        // -SukunFakeAlarm 20: show a set Fajr alarm (the simulator can't allow AlarmKit).
        if let alarm = defaults.string(forKey: "SukunFakeAlarm").flatMap(Int.init) {
            FajrAlarms.previewAuthorized = true
            model.update { $0.fajrAlarmMinutesBefore = alarm }
        } else {
            model.update { $0.fajrAlarmMinutesBefore = nil } // a previous run's fake alarm must not leak into other shots
        }
        // -SukunOpenFajrSheet YES: open the Fajr sheet on launch (App Store screenshot of the alarm).
        if defaults.bool(forKey: "SukunOpenFajrSheet") { model.showsFajrSheet = true }
        if let preview = defaults.string(forKey: "SukunDesignPreview").flatMap(PrayerKind.init(rawValue:)) {
            // "m5" means 5 minutes before (a leading "-" would read as another launch argument).
            let minutes = defaults.string(forKey: "SukunPreviewMinutes")
                .flatMap { Double($0.replacingOccurrences(of: "m", with: "-")) } ?? 10
            model.setDesignPreview(preview, day: day, minutesAfter: minutes)
        }
        // The shooting script reads this to set the simulator's status bar clock to the time on screen.
        let shown = Int(model.now().timeIntervalSince1970)
        try? "\(shown) \(location.timeZoneIdentifier)".write(to: URL.temporaryDirectory.appending(path: "screenshot-time"),
                                                             atomically: true, encoding: .utf8)
    }

    private static func location(for city: String) -> StoredLocation? {
        let (lat, lon, name, country, zone): (Double, Double, String, String, String)
        switch city {
        case "london": (lat, lon, name, country, zone) = (51.5074, -0.1278, "London", "GB", "Europe/London")
        case "berlin": (lat, lon, name, country, zone) = (52.52, 13.405, "Berlin", "DE", "Europe/Berlin")
        case "berlin-ar": (lat, lon, name, country, zone) = (52.52, 13.405, "برلين", "DE", "Europe/Berlin")
        case "dubai": (lat, lon, name, country, zone) = (25.2048, 55.2708, "دبي", "AE", "Asia/Dubai")
        default: return nil
        }
        return StoredLocation(coordinate: Coordinate(latitude: lat, longitude: lon), name: name,
                              countryCode: country, timeZoneIdentifier: zone, source: .manual)
    }
}
#endif
