import Foundation

/// The stretch between sunrise and Dhuhr, when no obligatory prayer is running.
///
/// With `SukunSettings.showsMorningPeriods` on (default) it is split into three states, named in plain words:
/// the few minutes while the sun rises (no prayer), Duha, and the minutes shortly before Dhuhr (no prayer).
/// Off, it is one neutral "Morning". Either way the UI never features Dhuhr as if it were running already.
/// Sukun shows times and plain labels only, no rulings.
public struct MorningPeriod: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case sunrise, duha, beforeDhuhr, morning

        public var title: String {
            switch self {
            case .sunrise: PrayerKind.sunrise.localizedName
            case .duha: L10n.string("morning.duha", default: "Duha")
            case .beforeDhuhr: L10n.string("morning.beforeDhuhr", default: "Shortly before Dhuhr")
            case .morning: L10n.string("morning.morning", default: "Morning")
            }
        }

        public var symbolName: String {
            switch self {
            case .sunrise: PrayerKind.sunrise.symbolName
            case .duha, .morning: "sun.horizon"
            case .beforeDhuhr: PrayerKind.dhuhr.symbolName
            }
        }
    }

    /// Minutes after sunrise during which one doesn't pray. Common, cautious value; change here only.
    public static let sunriseWindow: TimeInterval = 15 * 60
    /// Minutes before Dhuhr (the sun at its zenith) during which one doesn't pray.
    public static let beforeDhuhrWindow: TimeInterval = 10 * 60

    public let kind: Kind
    /// When this state began (shown as the big time, like "Isha since 18:15").
    public let start: Date
    /// When this state ends.
    public let end: Date

    /// Set while one doesn't pray: the line under the time reads "No prayer until {end}".
    public var noPrayerUntil: Date? {
        kind == .sunrise || kind == .beforeDhuhr ? end : nil
    }

    /// The states between `sunrise` and `dhuhr`, in order, without gaps or overlaps.
    public static func periods(sunrise: Date, dhuhr: Date, detailed: Bool) -> [MorningPeriod] {
        guard sunrise < dhuhr else { return [] }
        guard detailed else { return [MorningPeriod(kind: .morning, start: sunrise, end: dhuhr)] }
        let duhaStart = sunrise.addingTimeInterval(sunriseWindow)
        let duhaEnd = dhuhr.addingTimeInterval(-beforeDhuhrWindow)
        // Very short mornings (far north, heavy adjustments): one no-prayer stretch until Dhuhr.
        guard duhaStart < duhaEnd else { return [MorningPeriod(kind: .sunrise, start: sunrise, end: dhuhr)] }
        return [
            MorningPeriod(kind: .sunrise, start: sunrise, end: duhaStart),
            MorningPeriod(kind: .duha, start: duhaStart, end: duhaEnd),
            MorningPeriod(kind: .beforeDhuhr, start: duhaEnd, end: dhuhr),
        ]
    }
}

extension PrayerSnapshot {
    /// "No prayer until 07:32" during the two no-prayer windows, else nil.
    public var noPrayerLine: String? {
        morning?.noPrayerUntil.map {
            L10n.format("morning.noPrayerUntil", default: "No prayer until %@", formatter.string(from: $0))
        }
    }

    /// Spoken summary of the morning state for VoiceOver, else nil.
    public var morningAccessibilityText: String? {
        guard let morning else { return nil }
        let since = formatter.string(from: morning.start)
        if let until = morning.noPrayerUntil {
            return L10n.format("morning.a11y.noPrayer", default: "%1$@ since %2$@. No prayer until %3$@.",
                               morning.kind.title, since, formatter.string(from: until))
        }
        return L10n.format("morning.a11y.next", default: "%1$@ since %2$@. Next: %3$@ at %4$@.",
                           morning.kind.title, since, upcoming.kind.localizedName, formatter.string(from: upcoming.date))
    }
}
