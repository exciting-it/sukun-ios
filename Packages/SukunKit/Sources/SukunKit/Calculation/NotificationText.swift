import Foundation

/// Localized title and body for a planned notification. Lives in the kit so the app and the widget
/// extension (which also reschedules) write identical notifications.
public enum NotificationText {
    public static func content(for item: PlannedNotification, formatter: PrayerTimeFormatter) -> (title: String, body: String) {
        switch item.content {
        case .prayer(let slot, let ramadan):
            let name = slot.kind.localizedName
            let time = formatter.string(from: slot.date)
            switch ramadan {
            case .suhoorEnded: return (name, L10n.format("notification.suhoorEnded", default: "Suhoor has ended · %@", time))
            case .iftar: return (name, L10n.format("notification.iftar", default: "Time for Iftar · %@", time))
            case nil: return (name, L10n.format("notification.prayer", default: "It’s time for %1$@ · %2$@", name, time))
            }
        case .early(let slot, let minutes):
            let name = slot.kind.localizedName
            return (name, L10n.format("notification.early", default: "%1$@ in %2$lld min · %3$@",
                                      name, minutes, formatter.string(from: slot.date)))
        case .jumuah(let dhuhr):
            return (L10n.string("notification.jumuah.title", default: "Jumu'ah"),
                    L10n.format("notification.jumuah", default: "Today · Dhuhr %@", formatter.string(from: dhuhr.date)))
        case .suhoor(let fajr, let minutes):
            return (L10n.string("notification.suhoor.title", default: "Suhoor"),
                    L10n.format("notification.suhoor", default: "Suhoor ends in %1$lld min · Fajr %2$@",
                                minutes, formatter.string(from: fajr.date)))
        case .openApp:
            return ("Sukun", L10n.string("notification.openApp", default: "Open Sukun to keep your prayer reminders coming."))
        }
    }
}
