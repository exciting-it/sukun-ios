#if canImport(CoreLocation) && !os(Linux)
import CoreLocation
import Foundation

/// One-shot location request with a timeout. Works in both the app and the widget extension.
@MainActor
public final class OneShotLocationRequest: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Returns a fresh location, or the cached one if the request fails / times out.
    public func location(timeout: TimeInterval = 8) async -> CLLocation? {
        await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            continuation = cont
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish(self?.manager.location)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in self.finish(last) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(self.manager.location) }
    }
}

public enum LocationResolver {
    /// Distance under which a new GPS fix reuses the stored place name / time zone (no re-geocoding).
    static let reuseRadiusKm = 3.0

    /// Turns a CLLocation into a `StoredLocation`, reverse-geocoding only when the place actually changed.
    public static func storedLocation(
        for location: CLLocation,
        previous: StoredLocation?,
        geocodeTimeout: TimeInterval = 5
    ) async -> StoredLocation {
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        // Stamp with the fix's own time: a cached (stale) fix must not count as fresh and block the next refresh.
        let fixDate = min(location.timestamp, Date())
        if let previous, previous.coordinate.distanceKilometers(to: coordinate) < reuseRadiusKm {
            var updated = previous
            updated.coordinate = coordinate
            updated.updatedAt = fixDate
            return updated
        }
        let placemark = await reverseGeocode(location, timeout: geocodeTimeout)
        return StoredLocation(
            coordinate: coordinate,
            name: placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea,
            countryCode: placemark?.isoCountryCode,
            timeZoneIdentifier: placemark?.timeZone?.identifier ?? TimeZone.current.identifier,
            source: .gps,
            updatedAt: fixDate
        )
    }

    public static func reverseGeocode(_ location: CLLocation, timeout: TimeInterval) async -> CLPlacemark? {
        await withTaskGroup(of: CLPlacemark?.self) { group in
            group.addTask {
                try? await CLGeocoder().reverseGeocodeLocation(location).first
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// Resolves the location to use inside the widget extension.
    /// Manual override wins; otherwise a fresh GPS fix if the user granted widget location access,
    /// falling back to the last location the app stored.
    @MainActor
    public static func resolveForWidget(store: SharedStore = .shared) async -> StoredLocation? {
        let settings = store.settings
        if settings.useManualLocation, let manual = settings.manualLocation { return manual }

        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates else { return store.effectiveLocation }

        // Avoid hammering GPS: a fix younger than 15 minutes is good enough for prayer times.
        if let stored = store.gpsLocation, Date().timeIntervalSince(stored.updatedAt) < 15 * 60 {
            return stored
        }
        guard let fix = await OneShotLocationRequest().location(timeout: 6) else {
            return store.effectiveLocation
        }
        let resolved = await storedLocation(for: fix, previous: store.gpsLocation, geocodeTimeout: 4)
        store.gpsLocation = resolved
        return resolved
    }
}
#endif
