import Foundation

/// Calculation methods offered in Settings. `automatic` picks a regional default from the location's country.
public enum CalculationMethodOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic
    case muslimWorldLeague
    case ummAlQura
    case turkey
    case northAmerica
    case egyptian
    case dubai
    case karachi
    case kuwait
    case qatar
    case singapore
    case tehran
    case moonsightingCommittee

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .automatic: L10n.string("method.automatic", default: "Automatic (by region)")
        case .muslimWorldLeague: L10n.string("method.mwl", default: "Muslim World League")
        case .ummAlQura: L10n.string("method.ummAlQura", default: "Umm al-Qura, Makkah")
        case .turkey: L10n.string("method.turkey", default: "Diyanet (Türkiye)")
        case .northAmerica: L10n.string("method.isna", default: "ISNA (North America)")
        case .egyptian: L10n.string("method.egyptian", default: "Egyptian General Authority")
        case .dubai: L10n.string("method.dubai", default: "Dubai")
        case .karachi: L10n.string("method.karachi", default: "University of Islamic Sciences, Karachi")
        case .kuwait: L10n.string("method.kuwait", default: "Kuwait")
        case .qatar: L10n.string("method.qatar", default: "Qatar")
        case .singapore: L10n.string("method.singapore", default: "Singapore / Southeast Asia")
        case .tehran: L10n.string("method.tehran", default: "Institute of Geophysics, Tehran")
        case .moonsightingCommittee: L10n.string("method.moonsighting", default: "Moonsighting Committee")
        }
    }
}

public enum MadhabOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic, shafi, hanafi
    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .automatic: L10n.string("madhab.automatic", default: "Automatic (by region)")
        case .shafi: L10n.string("madhab.shafi", default: "Standard (Shafiʿi, Maliki, Hanbali)")
        case .hanafi: L10n.string("madhab.hanafi", default: "Hanafi")
        }
    }
}

public enum HighLatitudeOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic, middleOfTheNight, seventhOfTheNight, twilightAngle
    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .automatic: L10n.string("highlat.automatic", default: "Automatic")
        case .middleOfTheNight: L10n.string("highlat.middle", default: "Middle of the night")
        case .seventhOfTheNight: L10n.string("highlat.seventh", default: "Seventh of the night")
        case .twilightAngle: L10n.string("highlat.angle", default: "Twilight angle")
        }
    }
}

public enum ClockFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case system, twelveHour, twentyFourHour
    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .system: L10n.string("clock.system", default: "System")
        case .twelveHour: L10n.string("clock.12h", default: "12-hour")
        case .twentyFourHour: L10n.string("clock.24h", default: "24-hour")
        }
    }
}

/// All user preferences. Shared between app and widget through the App Group.
/// Decoding is tolerant: unknown or missing keys fall back to defaults so app updates never wipe settings.
public struct SukunSettings: Codable, Hashable, Sendable {
    public var method: CalculationMethodOption = .automatic
    public var madhab: MadhabOption = .automatic
    public var highLatitude: HighLatitudeOption = .automatic
    public var clockFormat: ClockFormat = .system
    public var useManualLocation: Bool = false
    public var manualLocation: StoredLocation?
    public var notificationsEnabled: Set<PrayerKind> = []
    public var showsPattern: Bool = true
    public var qiblaHaptics: Bool = true
    /// Minutes added to each time to match a mosque timetable (-30…30). Missing kinds mean 0.
    public var adjustments: [PrayerKind: Int] = [:]
    /// "Remind me before": minutes before each prayer whose notification is on, or nil.
    public var earlyReminderMinutes: Int?
    public var jumuahReminder: JumuahReminder?
    public var ramadanMode: RamadanMode = .automatic
    /// Minutes before Fajr while Ramadan mode is active, or nil.
    public var suhoorReminderMinutes: Int?
    /// Shifts the Hijri calendar by whole days (-2…2) to match the local start of the month.
    public var hijriAdjustmentDays: Int = 0

    public init() {}

    public func adjustment(for kind: PrayerKind) -> Int { adjustments[kind] ?? 0 }

    public var hasAdjustments: Bool { adjustments.values.contains { $0 != 0 } }

    enum CodingKeys: String, CodingKey {
        case method, madhab, highLatitude, clockFormat, useManualLocation, manualLocation
        case notificationsEnabled, showsPattern, qiblaHaptics
        case adjustments, earlyReminderMinutes, jumuahReminder, ramadanMode, suhoorReminderMinutes, hijriAdjustmentDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SukunSettings()
        method = (try? c.decodeIfPresent(CalculationMethodOption.self, forKey: .method)) ?? d.method
        madhab = (try? c.decodeIfPresent(MadhabOption.self, forKey: .madhab)) ?? d.madhab
        highLatitude = (try? c.decodeIfPresent(HighLatitudeOption.self, forKey: .highLatitude)) ?? d.highLatitude
        clockFormat = (try? c.decodeIfPresent(ClockFormat.self, forKey: .clockFormat)) ?? d.clockFormat
        useManualLocation = (try? c.decodeIfPresent(Bool.self, forKey: .useManualLocation)) ?? d.useManualLocation
        manualLocation = try? c.decodeIfPresent(StoredLocation.self, forKey: .manualLocation)
        let kinds = (try? c.decodeIfPresent([String].self, forKey: .notificationsEnabled)) ?? []
        notificationsEnabled = Set(kinds.compactMap(PrayerKind.init(rawValue:)))
        showsPattern = (try? c.decodeIfPresent(Bool.self, forKey: .showsPattern)) ?? d.showsPattern
        qiblaHaptics = (try? c.decodeIfPresent(Bool.self, forKey: .qiblaHaptics)) ?? d.qiblaHaptics

        let range = ReminderChoices.adjustmentRange
        let rawAdjustments = (try? c.decodeIfPresent([String: Int].self, forKey: .adjustments)) ?? [:]
        adjustments = rawAdjustments.reduce(into: [:]) { result, entry in
            guard let kind = PrayerKind(rawValue: entry.key), entry.value != 0 else { return }
            result[kind] = min(max(entry.value, range.lowerBound), range.upperBound)
        }
        earlyReminderMinutes = (try? c.decodeIfPresent(Int.self, forKey: .earlyReminderMinutes))
            .flatMap { ReminderChoices.early.contains($0) ? $0 : nil }
        jumuahReminder = (try? c.decodeIfPresent(JumuahReminder.self, forKey: .jumuahReminder))??.validated()
        ramadanMode = (try? c.decodeIfPresent(RamadanMode.self, forKey: .ramadanMode)) ?? d.ramadanMode
        suhoorReminderMinutes = (try? c.decodeIfPresent(Int.self, forKey: .suhoorReminderMinutes))
            .flatMap { ReminderChoices.suhoor.contains($0) ? $0 : nil }
        let hijri = ReminderChoices.hijriAdjustmentRange
        let rawHijri = (try? c.decodeIfPresent(Int.self, forKey: .hijriAdjustmentDays)) ?? d.hijriAdjustmentDays
        hijriAdjustmentDays = min(max(rawHijri, hijri.lowerBound), hijri.upperBound)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(method, forKey: .method)
        try c.encode(madhab, forKey: .madhab)
        try c.encode(highLatitude, forKey: .highLatitude)
        try c.encode(clockFormat, forKey: .clockFormat)
        try c.encode(useManualLocation, forKey: .useManualLocation)
        try c.encodeIfPresent(manualLocation, forKey: .manualLocation)
        try c.encode(notificationsEnabled.map(\.rawValue).sorted(), forKey: .notificationsEnabled)
        try c.encode(showsPattern, forKey: .showsPattern)
        try c.encode(qiblaHaptics, forKey: .qiblaHaptics)
        let nonZero = adjustments.filter { $0.value != 0 }
        try c.encode(Dictionary(uniqueKeysWithValues: nonZero.map { ($0.key.rawValue, $0.value) }), forKey: .adjustments)
        try c.encodeIfPresent(earlyReminderMinutes, forKey: .earlyReminderMinutes)
        try c.encodeIfPresent(jumuahReminder, forKey: .jumuahReminder)
        try c.encode(ramadanMode, forKey: .ramadanMode)
        try c.encodeIfPresent(suhoorReminderMinutes, forKey: .suhoorReminderMinutes)
        try c.encode(hijriAdjustmentDays, forKey: .hijriAdjustmentDays)
    }
}
