import CoreLocation
import Observation

/// Tracks location authorization for the app. Actual fixes are obtained via `OneShotLocationRequest`.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored var onAuthorizationChange: (() -> Void)?

    private(set) var authorization: CLAuthorizationStatus

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != self.authorization else { return }
            self.authorization = status
            self.onAuthorizationChange?()
        }
    }
}
