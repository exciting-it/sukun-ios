import Foundation

/// What Ramadan mode shows right now: the countdown to Iftar during the fast, to the end of Suhoor at night.
public struct RamadanState: Hashable, Sendable {
    public enum Countdown: Hashable, Sendable {
        case iftar(Date)
        case suhoorEnds(Date)

        public var date: Date {
            switch self {
            case .iftar(let date), .suhoorEnds(let date): date
            }
        }
    }

    public let countdown: Countdown
}

public enum Ramadan {
    /// True when the civil day containing `date` (location time zone) is in Hijri month 9.
    public static func isRamadanDay(_ date: Date, timeZone: TimeZone, adjustmentDays: Int) -> Bool {
        HijriDate.components(for: date, timeZone: timeZone, adjustmentDays: adjustmentDays).month == 9
    }

    /// Ramadan state at `date`. Automatic mode follows the Islamic day, which starts at Maghrib: active from
    /// Maghrib on the eve of 1 Ramadan until Maghrib on its last day.
    static func state(
        at date: Date,
        today: DaySchedule,
        calculator: PrayerCalculator,
        settings: SukunSettings
    ) -> RamadanState? {
        guard let fajr = today.time(for: .fajr), let maghrib = today.time(for: .maghrib) else { return nil }
        let active: Bool
        switch settings.ramadanMode {
        case .off: active = false
        case .on: active = true
        case .automatic:
            let islamicDay = date >= maghrib
                ? calculator.calendar.date(byAdding: .day, value: 1, to: today.day) ?? date
                : date
            active = isRamadanDay(islamicDay, timeZone: calculator.timeZone,
                                  adjustmentDays: settings.hijriAdjustmentDays)
        }
        guard active else { return nil }

        if fajr <= date && date < maghrib { return RamadanState(countdown: .iftar(maghrib)) }
        let nextFajr = calculator
            .slots(from: date.addingTimeInterval(1), to: date.addingTimeInterval(2 * 86_400))
            .first { $0.kind == .fajr }
        return nextFajr.map { RamadanState(countdown: .suhoorEnds($0.date)) }
    }
}
