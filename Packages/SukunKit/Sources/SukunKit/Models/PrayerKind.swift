import Foundation

/// The six daily events shown by Sukun. `sunrise` is not a prayer, it marks the end of the Fajr window.
public enum PrayerKind: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    public var id: String { rawValue }

    /// The five obligatory prayers (everything except sunrise).
    public static let obligatory: [PrayerKind] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    public var isObligatory: Bool { self != .sunrise }

    public var localizedName: String {
        switch self {
        case .fajr: L10n.string("prayer.fajr", default: "Fajr")
        case .sunrise: L10n.string("prayer.sunrise", default: "Sunrise")
        case .dhuhr: L10n.string("prayer.dhuhr", default: "Dhuhr")
        case .asr: L10n.string("prayer.asr", default: "Asr")
        case .maghrib: L10n.string("prayer.maghrib", default: "Maghrib")
        case .isha: L10n.string("prayer.isha", default: "Isha")
        }
    }

    /// SF Symbol used in compact layouts.
    public var symbolName: String {
        switch self {
        case .fajr: "sun.haze"
        case .sunrise: "sunrise"
        case .dhuhr: "sun.max"
        case .asr: "sun.min"
        case .maghrib: "sunset"
        case .isha: "moon.stars"
        }
    }
}

/// A single computed prayer time.
public struct PrayerSlot: Hashable, Codable, Sendable, Identifiable {
    public let kind: PrayerKind
    public let date: Date

    public init(kind: PrayerKind, date: Date) {
        self.kind = kind
        self.date = date
    }

    public var id: String { "\(kind.rawValue)-\(Int(date.timeIntervalSince1970))" }
}
