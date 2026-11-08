import Foundation
@testable import SukunKit

enum Fixtures {
    static let munich = StoredLocation(
        coordinate: Coordinate(latitude: 48.1351, longitude: 11.5820),
        name: "München", countryCode: "DE", timeZoneIdentifier: "Europe/Berlin", source: .manual
    )
    static let mecca = StoredLocation(
        coordinate: Coordinate(latitude: 21.4225, longitude: 39.8262),
        name: "Makkah", countryCode: "SA", timeZoneIdentifier: "Asia/Riyadh", source: .manual
    )

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, tz: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: tz)!
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static func settings(method: CalculationMethodOption, madhab: MadhabOption = .shafi) -> SukunSettings {
        var s = SukunSettings()
        s.method = method
        s.madhab = madhab
        return s
    }
}
