import Foundation

public enum QiblaCalculator {
    /// Coordinates of the Kaaba in Makkah.
    public static let kaaba = Coordinate(latitude: 21.4225241, longitude: 39.8261818)

    /// Initial great-circle bearing from `origin` to the Kaaba, in degrees clockwise from true north (0..<360).
    public static func bearing(from origin: Coordinate) -> Double {
        let phi = origin.latitude.radians
        let phiK = kaaba.latitude.radians
        let dLambda = (kaaba.longitude - origin.longitude).radians
        let y = sin(dLambda)
        let x = cos(phi) * tan(phiK) - sin(phi) * cos(dLambda)
        return CompassAngle.normalized(atan2(y, x).degrees)
    }

    /// Great-circle distance to the Kaaba in kilometres.
    public static func distanceKilometers(from origin: Coordinate) -> Double {
        origin.distanceKilometers(to: kaaba)
    }
}

public enum CompassAngle {
    /// Wraps any angle into 0..<360.
    public static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Smallest signed difference `to - from` in -180...180.
    public static func delta(from: Double, to: Double) -> Double {
        var d = normalized(to) - normalized(from)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}

/// Eight-point compass rose labels.
public enum CompassPoint: Int, CaseIterable, Sendable {
    case north, northEast, east, southEast, south, southWest, west, northWest

    public init(degrees: Double) {
        let index = Int((CompassAngle.normalized(degrees) + 22.5) / 45) % 8
        self = CompassPoint(rawValue: index)!
    }

    public var abbreviation: String {
        switch self {
        case .north: L10n.string("compass.n", default: "N")
        case .northEast: L10n.string("compass.ne", default: "NE")
        case .east: L10n.string("compass.e", default: "E")
        case .southEast: L10n.string("compass.se", default: "SE")
        case .south: L10n.string("compass.s", default: "S")
        case .southWest: L10n.string("compass.sw", default: "SW")
        case .west: L10n.string("compass.w", default: "W")
        case .northWest: L10n.string("compass.nw", default: "NW")
        }
    }

    public var localizedName: String {
        switch self {
        case .north: L10n.string("compass.north", default: "North")
        case .northEast: L10n.string("compass.northeast", default: "Northeast")
        case .east: L10n.string("compass.east", default: "East")
        case .southEast: L10n.string("compass.southeast", default: "Southeast")
        case .south: L10n.string("compass.south", default: "South")
        case .southWest: L10n.string("compass.southwest", default: "Southwest")
        case .west: L10n.string("compass.west", default: "West")
        case .northWest: L10n.string("compass.northwest", default: "Northwest")
        }
    }
}
