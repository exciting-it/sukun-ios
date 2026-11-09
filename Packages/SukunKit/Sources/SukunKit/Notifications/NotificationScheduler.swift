#if canImport(UserNotifications) && os(iOS)
import Foundation
import UserNotifications

/// Local notifications only. `NotificationPlan` decides what fires when within iOS's 64-request limit; this turns
/// the plan into requests. Called by the app (on launch, settings changes, background refresh) and by the widget
/// extension, which iOS wakes regularly even when the app has been swiped away, so reminders keep coming and follow
/// the user when they travel.
public enum NotificationScheduler {
    public static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default: return false
        }
    }

    public static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Replaces all pending Sukun notifications with a fresh plan and records what it was planned for.
    public static func reschedule(settings: SukunSettings, location: StoredLocation?,
                                  store: SharedStore = .shared, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("sukun.") }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard let location else {
            store.notificationStamp = nil
            return
        }
        let plan = NotificationPlan.make(settings: settings, location: location, now: now)
        store.notificationStamp = NotificationStamp(location: location, settings: settings, plan: plan)
        guard !plan.isEmpty else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let formatter = PrayerTimeFormatter(clockFormat: settings.clockFormat, timeZone: location.timeZone)
        for item in plan {
            let interval = item.fireDate.timeIntervalSince(now)
            guard interval > 1 else { continue }
            let text = NotificationText.content(for: item, formatter: formatter)
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            if let place = location.name, item.content != .openApp { content.subtitle = place }
            content.threadIdentifier = "sukun.prayers"
            if item.content == .openApp {
                content.interruptionLevel = .passive // quiet: no sound, no lighting up the screen
            } else {
                content.sound = .default
                content.interruptionLevel = .active
            }
            let request = UNNotificationRequest(
                identifier: item.id,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// For the widget extension: plans again only when location, settings or the remaining lead changed.
    public static func refreshIfNeeded(location: StoredLocation?, store: SharedStore = .shared, now: Date = Date()) async {
        guard let location else { return }
        let settings = store.settings
        guard NotificationStamp.needsReschedule(store.notificationStamp, location: location,
                                                settings: settings, now: now) else { return }
        await reschedule(settings: settings, location: location, store: store, now: now)
    }
}
#endif
