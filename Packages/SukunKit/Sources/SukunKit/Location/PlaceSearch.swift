#if canImport(MapKit) && !os(Linux)
import CoreLocation
import Foundation
import MapKit

/// City search for manual location entry (Apple Maps, no API key, no account).
public struct PlaceSearchResult: Identifiable, Hashable, Sendable {
    public let location: StoredLocation
    public let title: String
    public let subtitle: String
    public var id: String { "\(title)|\(subtitle)|\(location.coordinate.latitude),\(location.coordinate.longitude)" }
}

public enum PlaceSearch {
    public static func search(_ query: String) async -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        var seen = Set<String>()
        return response.mapItems.compactMap { item in
            let placemark = item.placemark
            let coordinate = Coordinate(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
            let city = placemark.locality ?? item.name ?? placemark.administrativeArea
            guard let city else { return nil }
            let subtitle = [placemark.administrativeArea, placemark.country]
                .compactMap { $0 }
                .filter { $0 != city }
                .joined(separator: ", ")
            guard seen.insert("\(city)|\(subtitle)").inserted else { return nil }
            let location = StoredLocation(
                coordinate: coordinate,
                name: city,
                countryCode: placemark.isoCountryCode,
                timeZoneIdentifier: item.timeZone?.identifier ?? TimeZone.current.identifier,
                source: .manual
            )
            return PlaceSearchResult(location: location, title: city, subtitle: subtitle)
        }
    }
}
#endif
