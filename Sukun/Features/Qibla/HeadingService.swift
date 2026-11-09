import CoreLocation
import Observation

/// Streams the device heading (true north when available, magnetic otherwise).
@MainActor
@Observable
final class HeadingService: NSObject, CLLocationManagerDelegate {
    @ObservationIgnored private let manager = CLLocationManager()

    /// Degrees clockwise from north, nil until the first reading.
    private(set) var heading: Double?
    /// Accuracy in degrees; negative means invalid (needs calibration).
    private(set) var accuracy: Double = -1
    private(set) var usesTrueNorth = false
    let isAvailable: Bool
    #if DEBUG
    /// Screenshot mode: a fixed reading instead of the compass (see `ScreenshotMode`).
    var simulatedHeading: Double?
    #endif

    override init() {
        #if DEBUG
        isAvailable = ScreenshotMode.fakeQiblaOffset != nil || CLLocationManager.headingAvailable()
        #else
        isAvailable = CLLocationManager.headingAvailable()
        #endif
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
        manager.headingOrientation = .portrait
    }

    func start() {
        #if DEBUG
        if let simulatedHeading {
            heading = simulatedHeading
            accuracy = 5
            usesTrueNorth = true
            return
        }
        #endif
        guard isAvailable else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    var needsCalibration: Bool {
        heading != nil && (accuracy < 0 || accuracy > 20)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let isTrue = newHeading.trueHeading >= 0
        let value = isTrue ? newHeading.trueHeading : newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.heading = value
            self.accuracy = accuracy
            self.usesTrueNorth = isTrue
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        false // We show our own gentle hint instead of the system overlay.
    }
}
