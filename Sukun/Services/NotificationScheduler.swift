import Foundation
import SukunKit
import UserNotifications

/// Wraps `UNAuthorizationStatus` so it can live in an @Observable model without Sendable noise.
struct UNAuthorizationStatusBox: Equatable {
    let value: UNAuthorizationStatus
    init(_ value: UNAuthorizationStatus) { self.value = value }
    var isDenied: Bool { value == .denied }
}

/// Local prayer notifications only. iOS allows 64 pending requests per app, so we schedule a rolling
/// window (up to 7 days) and refresh it whenever the app becomes active or a background refresh runs.
enum NotificationScheduler {
    static let identifierPrefix = "sukun.prayer."
    private static let maxRequests = 60

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default: return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(settings: SukunSettings, location: StoredLocation?, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        let enabled = settings.notificationsEnabled
        guard !enabled.isEmpty, let location else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let days = max(1, min(7, maxRequests / enabled.count))
        let calculator = PrayerCalculator(location: location, settings: settings)
        let formatter = PrayerTimeFormatter(clockFormat: settings.clockFormat, timeZone: location.timeZone)
        let slots = calculator
            .slots(from: now, to: now.addingTimeInterval(Double(days) * 86_400))
            .filter { enabled.contains($0.kind) }
            .prefix(maxRequests)

        for slot in slots {
            let content = UNMutableNotificationContent()
            let name = slot.kind.localizedName
            let time = formatter.string(from: slot.date)
            content.title = name
            content.body = String(localized: "It’s time for \(name) · \(time)")
            if let place = location.name { content.subtitle = place }
            content.sound = .default
            content.threadIdentifier = "sukun.prayers"
            content.interruptionLevel = .active

            let interval = slot.date.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let request = UNNotificationRequest(
                identifier: identifierPrefix + slot.id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try? await center.add(request)
        }
    }
}
