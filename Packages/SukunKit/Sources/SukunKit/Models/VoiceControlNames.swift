import Foundation

/// Extra names Voice Control accepts (`accessibilityInputLabels`). Dictation in English or German often doesn't
/// recognize Arabic terms ("Isha" comes out as "Aisha", "Maghrib" as "Maghreb"), so each item answers to its visible
/// name, a plain description in the user's language ("Night prayer") and common spellings.
public enum VoiceControlNames {
    public static var qibla: [String] {
        unique([
            L10n.string("voice.qibla", default: "Qibla"),
            L10n.string("voice.qibla.compass", default: "Compass"),
            L10n.string("voice.qibla.direction", default: "Prayer direction"),
            "Qibla", "Qiblah", "Kibla", "Kiblah",
        ])
    }

    static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

public extension PrayerKind {
    /// Visible name first, then a description in the user's language, then spellings dictation tends to produce.
    var voiceControlNames: [String] {
        VoiceControlNames.unique([localizedName, spokenDescription] + spellings)
    }

    private var spokenDescription: String {
        switch self {
        case .fajr: L10n.string("voice.fajr", default: "Dawn prayer")
        case .sunrise: L10n.string("voice.sunrise", default: "Sunrise")
        case .dhuhr: L10n.string("voice.dhuhr", default: "Noon prayer")
        case .asr: L10n.string("voice.asr", default: "Afternoon prayer")
        case .maghrib: L10n.string("voice.maghrib", default: "Sunset prayer")
        case .isha: L10n.string("voice.isha", default: "Night prayer")
        }
    }

    private var spellings: [String] {
        switch self {
        case .fajr: ["Fajr", "Fajar", "Fajer", "Fadschr"]
        case .sunrise: ["Sunrise", "Shuruq", "Shorouk"]
        case .dhuhr: ["Dhuhr", "Zuhr", "Zohr", "Duhr", "Dhuhur", "Zuhur"]
        case .asr: ["Asr", "Asar", "Asser", "Assr"]
        case .maghrib: ["Maghrib", "Magrib", "Maghreb"]
        case .isha: ["Isha", "Esha", "Eesha", "Ischa", "Aisha"]
        }
    }
}
