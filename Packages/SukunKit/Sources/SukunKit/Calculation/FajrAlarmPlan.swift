import Foundation

/// One Fajr alarm to schedule with AlarmKit.
public struct FajrAlarmItem: Hashable, Sendable {
    /// Stable for the same Fajr and offset, so planning again keeps existing alarms instead of churning them.
    public let id: UUID
    /// When the alarm rings.
    public let date: Date
    /// The Fajr time it wakes the user for.
    public let fajr: Date
    public let minutesBefore: Int
}

/// Fajr moves every day, so a repeating alarm can't follow it: plan one fixed alarm per day, a week ahead,
/// and top it up whenever reminders are planned (app, background refresh, widgets).
public enum FajrAlarmPlan {
    public static func make(settings: SukunSettings, location: StoredLocation, now: Date, days: Int = 7) -> [FajrAlarmItem] {
        guard let minutes = settings.fajrAlarmMinutesBefore else { return [] }
        let calculator = PrayerCalculator(location: location, settings: settings)
        let calendar = calculator.calendar
        var items: [FajrAlarmItem] = []
        var day = calendar.startOfDay(for: now)
        // days + 1 so a week of alarms remains even after today's has passed.
        for _ in 0...days {
            if let fajr = calculator.schedule(for: day)?.time(for: .fajr) {
                let date = fajr.addingTimeInterval(-Double(minutes) * 60)
                if date > now {
                    items.append(FajrAlarmItem(id: stableID(fajr: fajr, minutes: minutes), date: date,
                                               fajr: fajr, minutesBefore: minutes))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return Array(items.prefix(days))
    }

    /// A deterministic UUID: bytes 0–5 the Fajr instant (seconds, 48 bits), byte 6–7 version 4, byte 8 variant,
    /// byte 9 the offset, bytes 10–15 the tag "SUKUN". Nothing overlaps, so different alarms never collide.
    static func stableID(fajr: Date, minutes: Int) -> UUID {
        let seconds = UInt64(max(0, Int64(fajr.timeIntervalSince1970.rounded())))
        var b = [UInt8](repeating: 0, count: 16)
        for i in 0..<6 { b[i] = UInt8(truncatingIfNeeded: seconds >> (40 - 8 * i)) }
        b[6] = 0x40
        b[8] = 0x80
        b[9] = UInt8(clamping: minutes)
        for (i, c) in "SUKUN!".utf8.enumerated() { b[10 + i] = c }
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
