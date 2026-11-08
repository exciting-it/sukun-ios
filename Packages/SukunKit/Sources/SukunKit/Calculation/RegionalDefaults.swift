import Foundation

/// Regional defaults used when the user leaves method / madhab on "Automatic".
/// Based on what the official authority or most mosques in each country use.
public enum RegionalDefaults {
    public static func method(forCountryCode code: String?) -> CalculationMethodOption {
        switch code?.uppercased() {
        case "SA", "YE": .ummAlQura
        case "TR": .turkey
        case "AE": .dubai
        case "KW": .kuwait
        case "QA", "BH", "OM": .qatar
        case "EG", "SD", "LY", "SY", "LB", "IQ", "JO", "PS": .egyptian
        case "PK", "IN", "BD", "AF", "NP", "LK": .karachi
        case "US", "CA": .northAmerica
        case "SG", "MY", "ID", "BN", "TH", "PH": .singapore
        case "IR": .tehran
        case "GB", "IE": .moonsightingCommittee
        default: .muslimWorldLeague
        }
    }

    public static func madhab(forCountryCode code: String?) -> MadhabOption {
        switch code?.uppercased() {
        case "PK", "IN", "BD", "AF", "NP", "LK": .hanafi
        default: .shafi
        }
    }

    /// Above ~48° the sun may not reach the Fajr/Isha angles in summer; seventh-of-the-night gives
    /// realistic times there, middle-of-the-night is a safe guard below.
    public static func highLatitude(for coordinate: Coordinate) -> HighLatitudeOption {
        abs(coordinate.latitude) > 48 ? .seventhOfTheNight : .middleOfTheNight
    }
}
