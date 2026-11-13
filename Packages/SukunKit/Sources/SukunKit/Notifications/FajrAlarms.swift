import Foundation

#if canImport(AlarmKit) && os(iOS)
import AlarmKit
import AppIntents
import SwiftUI

/// What the Fajr alarm carries (AlarmKit shows it on the Lock Screen and in the Dynamic Island).
@available(iOS 26.1, *)
public struct SukunAlarmMetadata: AlarmMetadata {
    public var fajr: Date
    public init(fajr: Date) { self.fajr = fajr }
}
#endif

/// The Fajr alarm: a real alarm (AlarmKit, iOS 26.1+) that rings through silent mode and Focus, with snooze.
/// On older iOS, or without permission, the regular Fajr notification stays.
public enum FajrAlarms {
    /// Snooze length.
    public static let snooze: TimeInterval = 5 * 60
    /// Alarms are planned this many days ahead. The alarm must keep ringing every morning until the user turns it
    /// off, even if the app isn't opened for weeks; stopping an alarm also tops the plan up again (see `topUp`).
    public static let horizonDays = 30

    #if canImport(AlarmKit) && os(iOS)
    /// Set by the app and the widget extension: the intent that runs when an alarm is stopped (it lives in their
    /// targets, so the kit can't name it). It stops the alarm and plans the coming days again.
    nonisolated(unsafe) public static var stopIntent: ((UUID) -> any LiveActivityIntent)?
    #endif

    /// Plans the alarms again from what's stored (for intents and widgets, outside the app).
    public static func topUp(store: SharedStore = .shared) async {
        await sync(settings: store.settings, location: store.effectiveLocation)
    }

    public static var isSupported: Bool {
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) { return true }
        #endif
        return false
    }

    /// Debug screenshots only (the simulator can't grant AlarmKit): treat alarms as allowed for display.
    nonisolated(unsafe) public static var previewAuthorized = false

    public static var isAuthorized: Bool {
        if previewAuthorized { return true }
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) { return AlarmManager.shared.authorizationState == .authorized }
        #endif
        return false
    }

    public static var isDenied: Bool {
        if previewAuthorized { return false }
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) { return AlarmManager.shared.authorizationState == .denied }
        #endif
        return false
    }

    /// The alarm will really ring: turned on, supported and allowed. Only then does it replace the notification.
    public static func isActive(_ settings: SukunSettings) -> Bool {
        settings.fajrAlarmMinutesBefore != nil && isAuthorized
    }

    /// Asks once (iOS shows its own dialog); true when alarms may ring.
    public static func requestAuthorization() async -> Bool {
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized: return true
            case .denied: return false
            case .notDetermined: return ((try? await AlarmManager.shared.requestAuthorization()) ?? .denied) == .authorized
            @unknown default: return false
            }
        }
        #endif
        return false
    }

    /// Makes the scheduled alarms match the plan: keeps alarms that are still right (stable ids), schedules missing
    /// ones, cancels stale ones. Never touches an alarm that is ringing or snoozed right now. Idempotent and cheap,
    /// so the app, background refresh and widgets can all call it.
    public static func sync(settings: SukunSettings, location: StoredLocation?, now: Date = Date()) async {
        #if canImport(AlarmKit) && os(iOS)
        guard #available(iOS 26.1, *) else { return }
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }
        let plan = location.map { FajrAlarmPlan.make(settings: settings, location: $0, now: now, days: horizonDays) } ?? []
        let wanted = Set(plan.map(\.id))
        let existing = (try? manager.alarms) ?? []
        for alarm in existing where alarm.state == .scheduled && !wanted.contains(alarm.id) {
            try? manager.cancel(id: alarm.id)
        }
        let have = Set(existing.map(\.id))
        for item in plan where !have.contains(item.id) {
            do {
                _ = try await manager.schedule(id: item.id, configuration: configuration(for: item))
            } catch AlarmManager.AlarmError.maximumLimitReached {
                break // iOS caps alarms per app; the nearest days are scheduled first, the rest follow later
            } catch {
                continue
            }
        }
        #endif
    }

    /// Diagnostics: how many alarms are scheduled.
    public static var scheduledCount: Int {
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) { return ((try? AlarmManager.shared.alarms) ?? []).count }
        #endif
        return 0
    }

    /// Diagnostics: rings a Fajr-style alarm in `seconds` so testers needn't wait for dawn.
    @discardableResult
    public static func scheduleTest(in seconds: TimeInterval = 60) async -> Bool {
        #if canImport(AlarmKit) && os(iOS)
        if #available(iOS 26.1, *) {
            guard await requestAuthorization() else { return false }
            let date = Date().addingTimeInterval(seconds)
            let item = FajrAlarmItem(id: UUID(), date: date, fajr: date, minutesBefore: 0)
            return (try? await AlarmManager.shared.schedule(id: item.id, configuration: configuration(for: item))) != nil
        }
        #endif
        return false
    }

    #if canImport(AlarmKit) && os(iOS)
    @available(iOS 26.1, *)
    private static func configuration(for item: FajrAlarmItem) -> AlarmManager.AlarmConfiguration<SukunAlarmMetadata> {
        let title = LocalizedStringResource("prayer.fajr", defaultValue: "Fajr", bundle: .atURL(Bundle.module.bundleURL))
        let snoozeButton = AlarmButton(
            text: LocalizedStringResource("alarm.snooze", defaultValue: "Snooze", bundle: .atURL(Bundle.module.bundleURL)),
            textColor: .white, systemImageName: "zzz")
        let presentation = AlarmPresentation(
            alert: .init(title: title, secondaryButton: snoozeButton, secondaryButtonBehavior: .countdown),
            countdown: .init(title: title)
        )
        let attributes = AlarmAttributes(presentation: presentation, metadata: SukunAlarmMetadata(fajr: item.fajr),
                                         tintColor: Palette.accent)
        return AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snooze),
            schedule: .fixed(item.date),
            attributes: attributes,
            stopIntent: stopIntent?(item.id)
        )
    }
    #endif
}
