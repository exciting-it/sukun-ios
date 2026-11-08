import Adhan
import Foundation

/// Fully resolved calculation parameters (no "automatic" left) for one location.
public struct CalculationConfiguration: Hashable, Sendable {
    public var method: CalculationMethodOption
    public var madhab: MadhabOption
    public var highLatitude: HighLatitudeOption

    public init(method: CalculationMethodOption, madhab: MadhabOption, highLatitude: HighLatitudeOption) {
        self.method = method
        self.madhab = madhab
        self.highLatitude = highLatitude
    }

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
    }

    var adhanParameters: CalculationParameters {
        var params = adhanMethod.params
        params.madhab = madhab == .hanafi ? .hanafi : .shafi
        switch highLatitude {
        case .automatic, .middleOfTheNight: params.highLatitudeRule = .middleOfTheNight
        case .seventhOfTheNight: params.highLatitudeRule = .seventhOfTheNight
        case .twilightAngle: params.highLatitudeRule = .twilightAngle
        }
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
