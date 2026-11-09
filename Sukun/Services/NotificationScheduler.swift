import UserNotifications

/// Wraps `UNAuthorizationStatus` so it can live in an @Observable model without Sendable noise.
/// Scheduling itself lives in SukunKit (`NotificationScheduler`), shared with the widget extension.
struct UNAuthorizationStatusBox: Equatable {
    let value: UNAuthorizationStatus
    init(_ value: UNAuthorizationStatus) { self.value = value }
    var isDenied: Bool { value == .denied }
}
