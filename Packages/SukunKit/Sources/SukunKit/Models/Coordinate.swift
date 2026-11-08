import Foundation

public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    /// Great-circle distance in kilometres (haversine, mean Earth radius).
    public func distanceKilometers(to other: Coordinate) -> Double {
        let r = 6371.0088
        let phi1 = latitude.radians, phi2 = other.latitude.radians
        let dPhi = (other.latitude - latitude).radians
        let dLambda = (other.longitude - longitude).radians
        let a = sin(dPhi / 2) * sin(dPhi / 2) + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}

/// A location Sukun calculates prayer times for, either from GPS or entered manually.
public struct StoredLocation: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable { case gps, manual }

    public var coordinate: Coordinate
    /// Human-readable place name (city), if known.
    public var name: String?
    /// ISO 3166 country code, used to pick a regional default calculation method.
    public var countryCode: String?
    public var timeZoneIdentifier: String
    public var source: Source
    public var updatedAt: Date

    public init(
        coordinate: Coordinate,
        name: String? = nil,
        countryCode: String? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        source: Source,
        updatedAt: Date = Date()
    ) {
        self.coordinate = coordinate
        self.name = name
        self.countryCode = countryCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.source = source
        self.updatedAt = updatedAt
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

    public var displayName: String {
        if let name, !name.isEmpty { return name }
        return Self.formatCoordinate(coordinate)
    }

    public static func formatCoordinate(_ c: Coordinate) -> String {
        let lat = String(format: "%.2f°%@", abs(c.latitude), c.latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.2f°%@", abs(c.longitude), c.longitude >= 0 ? "E" : "W")
        return "\(lat) \(lon)"
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
