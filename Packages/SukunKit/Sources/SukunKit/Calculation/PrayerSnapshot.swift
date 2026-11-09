import Foundation

/// Everything a widget or screen needs to render "now": computed purely from location, settings and a date.
public struct PrayerSnapshot: Hashable, Sendable {
    public let date: Date
    public let location: StoredLocation
    public let settings: SukunSettings
    public let configuration: CalculationConfiguration
    /// Schedule of the civil day containing `date`. This is the list the UI shows.
    public let today: DaySchedule
    /// The obligatory prayer whose time is running now, or nil between sunrise and Dhuhr (Fajr ends at
    /// sunrise; no obligatory prayer is due until Dhuhr). After midnight this is yesterday's Isha, which
    /// lasts until Fajr, so it may not be part of `today`.
    public let current: PrayerSlot?
    /// The next boundary after `date`, sunrise included: the hint "Sunrise in 0:42" during Fajr tells
    /// when Fajr ends. Between sunrise and Dhuhr it is Dhuhr.
    public let upcoming: PrayerSlot
    /// Next obligatory prayer after `date` (may be tomorrow's Fajr).
    public let next: PrayerSlot
    /// Last boundary at or before `date` (may be sunrise or yesterday's Isha).
    public let previous: PrayerSlot
    public let period: DayPeriod
    /// Between sunrise and Dhuhr: the named morning state (Sunrise / Duha / Shortly before Dhuhr, or Morning).
    public let morning: MorningPeriod?
    /// Iftar / Suhoor countdown while Ramadan mode is active, else nil.
    public let ramadan: RamadanState?
    public let qiblaBearing: Double
    public let qiblaDistanceKilometers: Double

    public init?(date: Date, location: StoredLocation, settings: SukunSettings) {
        let calculator = PrayerCalculator(location: location, settings: settings)
        guard
            let today = calculator.schedule(for: date),
            let next = calculator.next(after: date),
            let upcoming = calculator.next(after: date, includeSunrise: true),
            let previous = calculator.previous(atOrBefore: date)
        else { return nil }
        self.date = date
        self.location = location
        self.settings = settings
        self.configuration = calculator.configuration
        self.today = today
        self.current = previous.kind.isObligatory ? previous : nil
        self.upcoming = upcoming
        self.next = next
        self.previous = previous
        self.period = DayPeriod(after: previous.kind)
        self.morning = previous.kind == .sunrise && upcoming.kind == .dhuhr
            ? MorningPeriod.periods(sunrise: previous.date, dhuhr: upcoming.date, detailed: settings.showsMorningPeriods)
                .first { $0.start <= date && date < $0.end }
            : nil
        self.ramadan = Ramadan.state(at: date, today: today, calculator: calculator, settings: settings)
        self.qiblaBearing = QiblaCalculator.bearing(from: location.coordinate)
        self.qiblaDistanceKilometers = QiblaCalculator.distanceKilometers(from: location.coordinate)
    }

    /// What the big display features: the current prayer, or the upcoming one when no prayer time is running.
    /// Displays should use `headline` / `headlineDate`, which name the morning state instead.
    public var featured: PrayerSlot { current ?? upcoming }

    /// Title of the big display: the running prayer, or the morning state between sunrise and Dhuhr.
    public var headline: String { morning?.kind.title ?? featured.kind.localizedName }

    /// The time under the title: when the running prayer or the morning state began.
    public var headlineDate: Date { morning?.start ?? featured.date }

    public var headlineSymbol: String { morning?.kind.symbolName ?? featured.kind.symbolName }

    /// Start of the interval the countdown ring measures (the last boundary, sunrise included).
    public var intervalStart: Date { previous.date }

    /// 0...1 progress from `previous` to `upcoming`.
    public var progress: Double {
        let total = upcoming.date.timeIntervalSince(previous.date)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(previous.date) / total))
    }

    public var formatter: PrayerTimeFormatter {
        PrayerTimeFormatter(clockFormat: settings.clockFormat, timeZone: location.timeZone)
    }

    /// Whether the listed day (`today`) is a fasting day: drives the "Iftar" / "Suhoor ends" row labels.
    /// Differs from `ramadan` around Maghrib: the eve's evening already counts down to Suhoor, but that
    /// Maghrib was no Iftar; the last day's Maghrib was an Iftar even though the countdown has ended.
    public var isRamadanDay: Bool {
        switch settings.ramadanMode {
        case .on: true
        case .off: false
        case .automatic: Ramadan.isRamadanDay(today.day, timeZone: location.timeZone,
                                              adjustmentDays: settings.hijriAdjustmentDays)
        }
    }

    public var hijriDate: String {
        HijriDate.string(for: date, timeZone: location.timeZone, adjustmentDays: settings.hijriAdjustmentDays)
    }

    public var qiblaCompassPoint: CompassPoint { CompassPoint(degrees: qiblaBearing) }

    /// True when `slot` is the prayer whose time is running now (the one the UI highlights).
    public func isCurrent(_ slot: PrayerSlot) -> Bool { slot == current }

    /// True for boundaries of `today` that are over: already started and not the running prayer.
    public func isPast(_ slot: PrayerSlot) -> Bool { slot.date <= date && slot != current }
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
        // Morning states switch between boundaries too (Sunrise → Duha → Shortly before Dhuhr).
        let around = calculator.slots(from: now.addingTimeInterval(-86_400), to: end)
        for (index, slot) in around.enumerated() where slot.kind == .sunrise {
            guard let dhuhr = around[(index + 1)...].first(where: { $0.kind == .dhuhr }) else { continue }
            dates += MorningPeriod.periods(sunrise: slot.date, dhuhr: dhuhr.date, detailed: settings.showsMorningPeriods)
                .map(\.start)
                .filter { $0 > now && $0 < end }
        }

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
