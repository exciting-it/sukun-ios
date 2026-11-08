import Foundation

/// Everything a widget or screen needs to render "now": computed purely from location, settings and a date.
public struct PrayerSnapshot: Hashable, Sendable {
    public let date: Date
    public let location: StoredLocation
    public let settings: SukunSettings
    public let configuration: CalculationConfiguration
    /// Schedule of the civil day containing `date`.
    public let today: DaySchedule
    /// The day whose list should be shown: today, or tomorrow once today's Isha has passed,
    /// so the upcoming prayer is always part of the visible list.
    public let displayDay: DaySchedule
    /// Next obligatory prayer after `date` (may be tomorrow's Fajr).
    public let next: PrayerSlot
    /// Last boundary at or before `date` (may be sunrise or yesterday's Isha).
    public let previous: PrayerSlot
    public let period: DayPeriod
    public let qiblaBearing: Double
    public let qiblaDistanceKilometers: Double

    public init?(date: Date, location: StoredLocation, settings: SukunSettings) {
        let calculator = PrayerCalculator(location: location, settings: settings)
        guard
            let today = calculator.schedule(for: date),
            let next = calculator.next(after: date),
            let previous = calculator.previous(atOrBefore: date),
            let displayDay = today.slots.contains(next) ? today : calculator.schedule(for: next.date)
        else { return nil }
        self.date = date
        self.location = location
        self.settings = settings
        self.configuration = calculator.configuration
        self.today = today
        self.displayDay = displayDay
        self.next = next
        self.previous = previous
        self.period = DayPeriod(after: previous.kind)
        self.qiblaBearing = QiblaCalculator.bearing(from: location.coordinate)
        self.qiblaDistanceKilometers = QiblaCalculator.distanceKilometers(from: location.coordinate)
    }

    /// Start of the interval the countdown ring measures (last obligatory prayer or sunrise before `next`).
    public var intervalStart: Date { previous.date }

    /// 0...1 progress from `previous` to `next`.
    public var progress: Double {
        let total = next.date.timeIntervalSince(previous.date)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(previous.date) / total))
    }

    public var formatter: PrayerTimeFormatter {
        PrayerTimeFormatter(clockFormat: settings.clockFormat, timeZone: location.timeZone)
    }

    public var hijriDate: String { HijriDate.string(for: date, timeZone: location.timeZone) }

    public var qiblaCompassPoint: CompassPoint { CompassPoint(degrees: qiblaBearing) }

    public var isShowingTomorrow: Bool { displayDay.day != today.day }

    /// True when `slot` is the one the UI should highlight as upcoming.
    public func isNext(_ slot: PrayerSlot) -> Bool { slot == next }
}

/// Widget timeline planning: the instants at which displayed content changes.
public enum PrayerTimeline {
    /// `now`, every prayer boundary (incl. sunrise) and every local midnight within `hours`, de-duplicated and sorted.
    public static func transitionDates(
        from now: Date,
        hours: Double = 48,
        location: StoredLocation,
        settings: SukunSettings
    ) -> [Date] {
        let end = now.addingTimeInterval(hours * 3600)
        let calculator = PrayerCalculator(location: location, settings: settings)
        var dates = calculator.slots(from: now, to: end).map(\.date)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        var midnight = cal.startOfDay(for: now)
        while let nextMidnight = cal.date(byAdding: .day, value: 1, to: midnight), nextMidnight < end {
            dates.append(nextMidnight)
            midnight = nextMidnight
        }
        dates.append(now)
        return Array(Set(dates.map { $0.timeIntervalSinceReferenceDate.rounded() }))
            .sorted()
            .map(Date.init(timeIntervalSinceReferenceDate:))
            .filter { $0 >= now.addingTimeInterval(-1) }
    }

    public static func snapshots(
        from now: Date,
        hours: Double = 48,
        location: StoredLocation,
        settings: SukunSettings
    ) -> [PrayerSnapshot] {
        transitionDates(from: now, hours: hours, location: location, settings: settings)
            .compactMap { PrayerSnapshot(date: $0, location: location, settings: settings) }
    }
}
