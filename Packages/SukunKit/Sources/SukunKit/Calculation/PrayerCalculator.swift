import Adhan
import Foundation

/// The six times of one civil day at a location.
public struct DaySchedule: Hashable, Sendable {
    /// Start of the civil day (midnight) in the location's time zone.
    public let day: Date
    public let slots: [PrayerSlot]

    public func time(for kind: PrayerKind) -> Date? {
        slots.first { $0.kind == kind }?.date
    }

    public var obligatory: [PrayerSlot] { slots.filter { $0.kind.isObligatory } }
}

/// Offline prayer time calculation for a single location (wraps Adhan).
public struct PrayerCalculator: Sendable {
    public let coordinate: Coordinate
    public let timeZone: TimeZone
    public let configuration: CalculationConfiguration

    public init(coordinate: Coordinate, timeZone: TimeZone, configuration: CalculationConfiguration) {
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.configuration = configuration
    }

    public init(location: StoredLocation, settings: SukunSettings) {
        self.init(
            coordinate: location.coordinate,
            timeZone: location.timeZone,
            configuration: CalculationConfiguration(settings: settings, location: location)
        )
    }

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// The schedule of the civil day (in the location's time zone) that contains `date`.
    public func schedule(for date: Date) -> DaySchedule? {
        let cal = calendar
        let components = cal.dateComponents([.year, .month, .day], from: date)
        guard
            let prayerTimes = PrayerTimes(
                coordinates: Coordinates(latitude: coordinate.latitude, longitude: coordinate.longitude),
                date: components,
                calculationParameters: configuration.adhanParameters
            )
        else { return nil }

        let slots: [PrayerSlot] = [
            PrayerSlot(kind: .fajr, date: prayerTimes.fajr),
            PrayerSlot(kind: .sunrise, date: prayerTimes.sunrise),
            PrayerSlot(kind: .dhuhr, date: prayerTimes.dhuhr),
            PrayerSlot(kind: .asr, date: prayerTimes.asr),
            PrayerSlot(kind: .maghrib, date: prayerTimes.maghrib),
            PrayerSlot(kind: .isha, date: prayerTimes.isha),
        ]
        return DaySchedule(day: cal.startOfDay(for: date), slots: slots)
    }

    /// All slots whose time falls in `[start, end)`, across day boundaries, sorted by time.
    public func slots(from start: Date, to end: Date, includeSunrise: Bool = true) -> [PrayerSlot] {
        guard start < end else { return [] }
        let cal = calendar
        var result: [PrayerSlot] = []
        // Start one day early so a slot belonging to "yesterday" that falls after `start` is never missed.
        var day = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: start)) ?? start
        while day < end {
            if let schedule = schedule(for: day) {
                result += schedule.slots.filter {
                    $0.date >= start && $0.date < end && (includeSunrise || $0.kind.isObligatory)
                }
            }
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return result.sorted { $0.date < $1.date }
    }

    /// The first slot strictly after `date`.
    public func next(after date: Date, includeSunrise: Bool = false) -> PrayerSlot? {
        slots(from: date.addingTimeInterval(1), to: date.addingTimeInterval(2 * 86_400), includeSunrise: includeSunrise).first
    }

    /// The latest slot at or before `date` (the prayer whose time is currently running).
    public func previous(atOrBefore date: Date, includeSunrise: Bool = true) -> PrayerSlot? {
        slots(from: date.addingTimeInterval(-2 * 86_400), to: date.addingTimeInterval(1), includeSunrise: includeSunrise).last
    }

    /// Period of the day, used for the background gradient.
    public func period(at date: Date) -> DayPeriod {
        guard let current = previous(atOrBefore: date) else { return .night }
        return DayPeriod(after: current.kind)
    }
}

/// Coarse periods of the day derived from prayer boundaries.
public enum DayPeriod: String, CaseIterable, Sendable {
    case dawn        // Fajr → Sunrise
    case morning     // Sunrise → Dhuhr
    case midday      // Dhuhr → Asr
    case afternoon   // Asr → Maghrib
    case dusk        // Maghrib → Isha
    case night       // Isha → Fajr

    public init(after kind: PrayerKind) {
        switch kind {
        case .fajr: self = .dawn
        case .sunrise: self = .morning
        case .dhuhr: self = .midday
        case .asr: self = .afternoon
        case .maghrib: self = .dusk
        case .isha: self = .night
        }
    }
}
