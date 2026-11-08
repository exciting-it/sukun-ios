import Foundation

/// Formats prayer times honoring the user's 12/24h preference and the location's time zone.
public struct PrayerTimeFormatter: Sendable {
    public let clockFormat: ClockFormat
    public let timeZone: TimeZone
    public let locale: Locale

    public init(clockFormat: ClockFormat, timeZone: TimeZone, locale: Locale = .current) {
        self.clockFormat = clockFormat
        self.timeZone = timeZone
        self.locale = locale
    }

    public func string(from date: Date) -> String {
        formatter(includePeriod: true).string(from: date)
    }

    /// The widest strings this formatter can produce ("12:58 AM/PM", "20:58"). Lay them out hidden behind a
    /// time to give a column a fixed width, so symbols next to it line up whatever the hour.
    public var widthSamples: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let day = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return [0, 12, 20].compactMap { hour in
            cal.date(bySettingHour: hour, minute: 58, second: 0, of: day).map(string(from:))
        }
    }

    /// Time without AM/PM marker, for large numerals. Pair with `periodSymbol(for:)`.
    public func numerals(from date: Date) -> String {
        formatter(includePeriod: false).string(from: date)
    }

    /// "AM"/"PM" when a 12-hour clock is in effect, otherwise nil.
    public func periodSymbol(for date: Date) -> String? {
        guard uses12Hour else { return nil }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = "a"
        return f.string(from: date)
    }

    public var uses12Hour: Bool {
        switch clockFormat {
        case .twelveHour: return true
        case .twentyFourHour: return false
        case .system:
            let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
            return format.contains("a")
        }
    }

    private func formatter(includePeriod: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        if uses12Hour {
            f.dateFormat = includePeriod ? "h:mm a" : "h:mm"
        } else {
            f.dateFormat = "HH:mm"
        }
        return f
    }
}

/// The civil (Gregorian) date line, e.g. "Monday, 9 November". Always Gregorian, even in locales whose default
/// calendar is Islamic (ar_SA), because the Hijri date is shown on its own line.
public enum CivilDate {
    public static func string(for date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = locale
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: date)
    }
}

public enum HijriDate {
    /// Localized Hijri date (Umm al-Qura calendar), e.g. "6 Rajab 1448 AH". `adjustmentDays` shifts it by whole
    /// days to match the local start of the month (+1 = one day later than the calendar).
    public static func string(for date: Date, timeZone: TimeZone, adjustmentDays: Int = 0, locale: Locale = .current) -> String {
        let date = shifted(date, by: adjustmentDays, timeZone: timeZone)
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        calendar.locale = locale
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = locale
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate("dMMMMyG")
        return f.string(from: date)
    }

    public static func components(for date: Date, timeZone: TimeZone, adjustmentDays: Int = 0) -> DateComponents {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.year, .month, .day], from: shifted(date, by: adjustmentDays, timeZone: timeZone))
    }

    private static func shifted(_ date: Date, by days: Int, timeZone: TimeZone) -> Date {
        guard days != 0 else { return date }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
}
