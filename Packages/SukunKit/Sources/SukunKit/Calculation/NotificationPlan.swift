import Foundation

/// How a Fajr or Maghrib notification reads during Ramadan.
public enum RamadanVariant: Hashable, Sendable {
    case suhoorEnded
    case iftar
}

/// One local notification Sukun should schedule. The app turns `content` into localized text.
public struct PlannedNotification: Hashable, Sendable {
    public enum Content: Hashable, Sendable {
        case prayer(PrayerSlot, ramadan: RamadanVariant?)
        case early(PrayerSlot, minutes: Int)
        case jumuah(dhuhr: PrayerSlot)
        case suhoor(fajr: PrayerSlot, minutes: Int)
        /// Last item of every plan: fires only if nothing (app, background refresh, widget) planned again.
        case openApp
    }

    public let id: String
    public let fireDate: Date
    public let content: Content
}

/// Decides which notifications fire when. Pure and deterministic, so the rules are tested here:
/// - at most `budget` items (iOS allows 64 pending; we keep headroom),
/// - at most one extra notification per prayer: Suhoor (Ramadan) beats Fajr's early reminder,
///   Jumu'ah (Friday) beats Dhuhr's early reminder,
/// - Jumu'ah and Suhoor don't need the prayer's own toggle,
/// - anything whose time has passed is skipped (late reminders are not sent late),
/// - days and weekdays are the location's, stepped with its calendar (safe across DST).
public enum NotificationPlan {
    public static let budget = 60

    public static func make(
        settings: SukunSettings,
        location: StoredLocation,
        now: Date,
        days: Int = 7
    ) -> [PlannedNotification] {
        let enabled = settings.notificationsEnabled
        guard !enabled.isEmpty || settings.jumuahReminder != nil || settings.suhoorReminderMinutes != nil else {
            return []
        }
        let calculator = PrayerCalculator(location: location, settings: settings)
        let calendar = calculator.calendar
        guard let end = calendar.date(byAdding: .day, value: days, to: now) else { return [] }

        var items: [PlannedNotification] = []
        // Start with yesterday: at high latitudes in summer its Isha can fall after midnight, i.e. after `now`.
        // The fireDate filter below drops everything already past.
        var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? calendar.startOfDay(for: now)
        while day < end {
            if let schedule = calculator.schedule(for: day) {
                items += plan(for: schedule, settings: settings, calendar: calendar, timeZone: location.timeZone)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        let real = Array(
            items
                .filter { $0.fireDate > now && $0.fireDate < end }
                .sorted { $0.fireDate < $1.fireDate }
                .prefix(budget - 1)
        )
        guard let last = real.last else { return [] }
        // Each new plan replaces this one, so it only shows when reminders were about to stop for good
        // (app swiped away for weeks and no widget placed).
        return real + [PlannedNotification(id: "sukun.openApp", fireDate: last.fireDate.addingTimeInterval(3600),
                                           content: .openApp)]
    }

    private static func plan(
        for schedule: DaySchedule,
        settings: SukunSettings,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> [PlannedNotification] {
        let isFriday = calendar.component(.weekday, from: schedule.day) == 6
        let isRamadanDay: Bool = switch settings.ramadanMode {
        case .on: true
        case .off: false
        case .automatic: Ramadan.isRamadanDay(schedule.day, timeZone: timeZone,
                                              adjustmentDays: settings.hijriAdjustmentDays)
        }

        var items: [PlannedNotification] = []
        for slot in schedule.obligatory {
            let prayerOn = settings.notificationsEnabled.contains(slot.kind)
            if prayerOn {
                let variant: RamadanVariant? = switch (isRamadanDay, slot.kind) {
                case (true, .fajr): .suhoorEnded
                case (true, .maghrib): .iftar
                default: nil
                }
                items.append(item("prayer", slot, at: slot.date, .prayer(slot, ramadan: variant)))
            }

            // At most one extra per prayer; the specific reminder wins over the generic one.
            if slot.kind == .fajr, isRamadanDay, let minutes = settings.suhoorReminderMinutes {
                items.append(item("suhoor", slot, at: slot.date.addingTimeInterval(-Double(minutes) * 60),
                                  .suhoor(fajr: slot, minutes: minutes)))
            } else if slot.kind == .dhuhr, isFriday, let jumuah = settings.jumuahReminder,
                      let fire = fireDate(for: jumuah, dhuhr: slot, day: schedule.day, calendar: calendar) {
                items.append(item("jumuah", slot, at: fire, .jumuah(dhuhr: slot)))
            } else if prayerOn, let minutes = settings.earlyReminderMinutes {
                items.append(item("early", slot, at: slot.date.addingTimeInterval(-Double(minutes) * 60),
                                  .early(slot, minutes: minutes)))
            }
        }
        return items
    }

    private static func fireDate(for reminder: JumuahReminder, dhuhr: PrayerSlot, day: Date, calendar: Calendar) -> Date? {
        switch reminder {
        case .beforeDhuhr(let minutes):
            dhuhr.date.addingTimeInterval(-Double(minutes) * 60)
        case .fixedTime(let hour, let minute):
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }
    }

    private static func item(_ tag: String, _ slot: PrayerSlot, at date: Date, _ content: PlannedNotification.Content) -> PlannedNotification {
        PlannedNotification(id: "sukun.\(tag).\(slot.kind.rawValue).\(Int(slot.date.timeIntervalSince1970))",
                            fireDate: date, content: content)
    }
}
