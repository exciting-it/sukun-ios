import Foundation
import SukunKit

/// Localized title and body for a planned notification.
enum NotificationText {
    static func content(for item: PlannedNotification, formatter: PrayerTimeFormatter) -> (title: String, body: String) {
        switch item.content {
        case .prayer(let slot, let ramadan):
            let name = slot.kind.localizedName
            let time = formatter.string(from: slot.date)
            switch ramadan {
            case .suhoorEnded: return (name, String(localized: "Suhoor has ended · \(time)"))
            case .iftar: return (name, String(localized: "Time for Iftar · \(time)"))
            case nil: return (name, String(localized: "It’s time for \(name) · \(time)"))
            }
        case .early(let slot, let minutes):
            let name = slot.kind.localizedName
            return (name, String(localized: "\(name) in \(minutes) min · \(formatter.string(from: slot.date))"))
        case .jumuah(let dhuhr):
            return (String(localized: "Jumu'ah"), String(localized: "Today · Dhuhr \(formatter.string(from: dhuhr.date))"))
        case .suhoor(let fajr, let minutes):
            return (String(localized: "Suhoor"),
                    String(localized: "Suhoor ends in \(minutes) min · Fajr \(formatter.string(from: fajr.date))"))
        }
    }
}
