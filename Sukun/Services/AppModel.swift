import CoreLocation
import Observation
import SukunKit
import SwiftUI
import UserNotifications
import WidgetKit

/// App-wide state. Persists everything to the App Group so widgets always see the same data.
@MainActor
@Observable
final class AppModel {
    private let store: SharedStore
    let locationService = LocationService()

    private(set) var settings: SukunSettings
    private(set) var gpsLocation: StoredLocation?
    private(set) var isLocating = false
    var notificationStatus: UNAuthorizationStatusBox = .init(.notDetermined)

    private let requestAuthorization: @Sendable () async -> Bool

    init(store: SharedStore = .shared,
         requestAuthorization: @escaping @Sendable () async -> Bool = { await NotificationScheduler.requestAuthorization() }) {
        self.store = store
        self.requestAuthorization = requestAuthorization
        settings = store.settings
        gpsLocation = store.gpsLocation
        locationService.onAuthorizationChange = { [weak self] in
            Task { await self?.refreshLocationIfPossible() }
        }
    }

    // MARK: Derived

    /// The location used for all calculations (manual override, otherwise GPS).
    var location: StoredLocation? {
        if settings.useManualLocation, let manual = settings.manualLocation { return manual }
        return gpsLocation ?? settings.manualLocation
    }

    // MARK: Design preview (debug builds only expose the UI; release keeps the offset at 0)

    /// Which time of day the preview shows, nil = live.
    private(set) var designPreview: PrayerKind?
    /// Virtual time minus real time while previewing.
    private(set) var previewOffset: TimeInterval = 0

    /// Jumps the app's clock to 10 minutes after `kind` today, so Today and Qibla look as they would then.
    /// `day` picks another date (screenshots of a Ramadan day); default is today.
    func setDesignPreview(_ kind: PrayerKind?, now: Date = Date(), day: Date? = nil, minutesAfter: Double = 10) {
        designPreview = kind
        guard let kind, let target = snapshot(at: day ?? now)?.today.time(for: kind) else {
            previewOffset = 0
            return
        }
        previewOffset = target.addingTimeInterval(minutesAfter * 60).timeIntervalSince(now)
    }

    /// The moment the UI should show for a real clock time.
    func now(_ real: Date = Date()) -> Date { real.addingTimeInterval(previewOffset) }

    /// Maps a virtual date back to the real clock, for `Text(date, style: .timer)` countdowns.
    func realDate(_ virtual: Date) -> Date { virtual.addingTimeInterval(-previewOffset) }

    func snapshot(at date: Date) -> PrayerSnapshot? {
        guard let location else { return nil }
        return PrayerSnapshot(date: date, location: location, settings: settings)
    }

    var locationAuthorization: CLAuthorizationStatus { locationService.authorization }

    var isLocationDenied: Bool {
        locationAuthorization == .denied || locationAuthorization == .restricted
    }

    // MARK: Lifecycle

    func sceneDidBecomeActive() {
        Task {
            await refreshLocationIfPossible()
            await refreshNotificationStatus()
            // Only when place, settings, permission or remaining days changed; settings edits reschedule directly.
            await NotificationScheduler.refreshIfNeeded(location: location, source: .app)
        }
    }

    // MARK: Settings

    func update(_ mutate: (inout SukunSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        guard copy != settings else { return }
        settings = copy
        store.settings = copy
        dataDidChange()
    }

    /// Binding into a single settings field, for Form controls.
    func binding<Value>(_ keyPath: WritableKeyPath<SukunSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    // MARK: Location

    func requestLocationPermission() {
        locationService.requestPermission()
    }

    func useManualLocation(_ location: StoredLocation) {
        update {
            $0.manualLocation = location
            $0.useManualLocation = true
        }
    }

    func useDeviceLocation() {
        update { $0.useManualLocation = false }
        if locationService.isAuthorized {
            Task { await refreshLocationIfPossible(force: true) }
        } else {
            requestLocationPermission()
        }
    }

    func refreshLocationIfPossible(force: Bool = false) async {
        guard locationService.isAuthorized, !isLocating else { return }
        if !force, let gps = gpsLocation, Date().timeIntervalSince(gps.updatedAt) < 10 * 60 { return }
        isLocating = true
        defer { isLocating = false }
        guard let fix = await OneShotLocationRequest().location(timeout: 10) else { return }
        let resolved = await LocationResolver.storedLocation(for: fix, previous: gpsLocation)
        let previous = gpsLocation
        gpsLocation = resolved
        store.gpsLocation = resolved
        let movedNoticeably = previous.map { $0.coordinate.distanceKilometers(to: resolved.coordinate) > 1 } ?? true
        if movedNoticeably || previous?.timeZoneIdentifier != resolved.timeZoneIdentifier {
            dataDidChange()
        }
    }

    // MARK: Notifications

    func setNotification(_ enabled: Bool, for kind: PrayerKind) async {
        guard await authorizeIfTurningOn(enabled) else { return }
        update {
            if enabled { $0.notificationsEnabled.insert(kind) } else { $0.notificationsEnabled.remove(kind) }
        }
    }

    func setEarlyReminder(_ minutes: Int?) async {
        guard await authorizeIfTurningOn(minutes != nil) else { return }
        update { $0.earlyReminderMinutes = minutes }
    }

    func setJumuahReminder(_ reminder: JumuahReminder?) async {
        guard await authorizeIfTurningOn(reminder != nil) else { return }
        update { $0.jumuahReminder = reminder }
    }

    func setSuhoorReminder(_ minutes: Int?) async {
        guard await authorizeIfTurningOn(minutes != nil) else { return }
        update { $0.suhoorReminderMinutes = minutes }
    }

    /// Turning a reminder on asks for notification permission first; turning off never does.
    private func authorizeIfTurningOn(_ turningOn: Bool) async -> Bool {
        guard turningOn else { return true }
        let granted = await requestAuthorization()
        await refreshNotificationStatus()
        return granted
    }

    func refreshNotificationStatus() async {
        notificationStatus = .init(await NotificationScheduler.authorizationStatus())
    }

    // MARK: Side effects

    private func dataDidChange() {
        WidgetCenter.shared.reloadAllTimelines()
        let settings = settings
        let location = location
        Task { await NotificationScheduler.reschedule(settings: settings, location: location) }
    }
}
