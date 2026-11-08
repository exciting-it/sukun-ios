import Adhan
import Foundation

/// Fully resolved calculation parameters (no "automatic" left) for one location.
public struct CalculationConfiguration: Hashable, Sendable {
    public var method: CalculationMethodOption
    public var madhab: MadhabOption
    public var highLatitude: HighLatitudeOption
    /// Per-time minute offsets on top of the method (to match a mosque timetable).
    public var adjustments: [PrayerKind: Int]

    public init(method: CalculationMethodOption, madhab: MadhabOption, highLatitude: HighLatitudeOption,
                adjustments: [PrayerKind: Int] = [:]) {
        self.method = method
        self.madhab = madhab
        self.highLatitude = highLatitude
        self.adjustments = adjustments
    }

    public var isAdjusted: Bool { adjustments.values.contains { $0 != 0 } }

    /// Resolves "automatic" choices using the location's country and latitude.
    public init(settings: SukunSettings, location: StoredLocation) {
        method = settings.method == .automatic
            ? RegionalDefaults.method(forCountryCode: location.countryCode)
            : settings.method
        madhab = settings.madhab == .automatic
            ? RegionalDefaults.madhab(forCountryCode: location.countryCode)
            : settings.madhab
        highLatitude = settings.highLatitude == .automatic
            ? RegionalDefaults.highLatitude(for: location.coordinate)
            : settings.highLatitude
        adjustments = settings.adjustments
    }

    var adhanParameters: CalculationParameters {
        var params = adhanMethod.params
        params.madhab = madhab == .hanafi ? .hanafi : .shafi
        switch highLatitude {
        case .automatic, .middleOfTheNight: params.highLatitudeRule = .middleOfTheNight
        case .seventhOfTheNight: params.highLatitudeRule = .seventhOfTheNight
        case .twilightAngle: params.highLatitudeRule = .twilightAngle
        }
        params.adjustments = PrayerAdjustments(
            fajr: adjustments[.fajr] ?? 0, sunrise: adjustments[.sunrise] ?? 0, dhuhr: adjustments[.dhuhr] ?? 0,
            asr: adjustments[.asr] ?? 0, maghrib: adjustments[.maghrib] ?? 0, isha: adjustments[.isha] ?? 0
        )
        return params
    }

    private var adhanMethod: CalculationMethod {
        switch method {
        case .automatic, .muslimWorldLeague: .muslimWorldLeague
        case .ummAlQura: .ummAlQura
        case .turkey: .turkey
        case .northAmerica: .northAmerica
        case .egyptian: .egyptian
        case .dubai: .dubai
        case .karachi: .karachi
        case .kuwait: .kuwait
        case .qatar: .qatar
        case .singapore: .singapore
        case .tehran: .tehran
        case .moonsightingCommittee: .moonsightingCommittee
        }
    }
}
