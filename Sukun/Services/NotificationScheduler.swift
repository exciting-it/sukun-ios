import Foundation
import SukunKit
import UserNotifications

/// Wraps `UNAuthorizationStatus` so it can live in an @Observable model without Sendable noise.
struct UNAuthorizationStatusBox: Equatable {
    let value: UNAuthorizationStatus
    init(_ value: UNAuthorizationStatus) { self.value = value }
    var isDenied: Bool { value == .denied }
}

/// Local notifications only. `NotificationPlan` (SukunKit) decides what fires when within iOS's 64-request
/// limit; this turns the plan into requests whenever the app becomes active or a background refresh runs.
enum NotificationScheduler {
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
            .filter { $0.hasPrefix("sukun.") }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard let location else { return }
        // The plan decides everything (budget, one extra per prayer, Jumu'ah/Suhoor without the prayer toggle).
        let plan = NotificationPlan.make(settings: settings, location: location, now: now)
        guard !plan.isEmpty else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let formatter = PrayerTimeFormatter(clockFormat: settings.clockFormat, timeZone: location.timeZone)
        for item in plan {
            let text = NotificationText.content(for: item, formatter: formatter)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            if let place = location.name { content.subtitle = place }
            content.sound = .default
            content.threadIdentifier = "sukun.prayers"
            content.interruptionLevel = .active

            let interval = item.fireDate.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let request = UNNotificationRequest(
                identifier: item.id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try? await center.add(request)
        }
    }
}
