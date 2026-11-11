import Foundation

/// What the pending notifications were planned for. The widget extension compares it with the current
/// location and settings on every timeline reload and plans again only when something changed or the
/// plan runs low, so reminders follow travel even when the app is never opened (swiped away).
public struct NotificationStamp: Codable, Hashable, Sendable {
    public var coordinate: Coordinate
    public var timeZoneIdentifier: String
    public var name: String?
    public var countryCode: String?
    public var settings: SukunSettings
    /// Fire date of the last real reminder in the plan; nil when nothing was planned.
    public var plannedUntil: Date?
    /// Whether notifications were allowed when planned (allowing them later in iOS Settings must plan again).
    public var authorized: Bool
    /// Whether the Fajr alarm was ringing instead of the Fajr notification (alarm permission can change outside the app).
    public var fajrAlarmActive: Bool = false

    /// Plan again when fewer than this many seconds of reminders are left.
    public static let minimumLead: TimeInterval = 3 * 86_400

    public init(location: StoredLocation, settings: SukunSettings, plan: [PlannedNotification], authorized: Bool = true,
                fajrAlarmActive: Bool = false) {
        self.authorized = authorized
        self.fajrAlarmActive = fajrAlarmActive
        coordinate = location.coordinate
        timeZoneIdentifier = location.timeZoneIdentifier
        name = location.name
        countryCode = location.countryCode
        self.settings = settings
        plannedUntil = plan.last { $0.content != .openApp }?.fireDate
    }

    /// `authorized` nil skips the permission check.
    public func needsReschedule(location: StoredLocation, settings: SukunSettings, now: Date,
                                authorized: Bool? = nil, fajrAlarmActive: Bool? = nil) -> Bool {
        if settings != self.settings { return true }
        if let authorized, authorized != self.authorized { return true }
        if let fajrAlarmActive, fajrAlarmActive != self.fajrAlarmActive { return true }
        if location.timeZoneIdentifier != timeZoneIdentifier || location.name != name
            || location.countryCode != countryCode { return true }
        if location.coordinate.distanceKilometers(to: coordinate) > 1 { return true }
        if let plannedUntil, plannedUntil.timeIntervalSince(now) < Self.minimumLead { return true }
        return false
    }

    public static func needsReschedule(_ stamp: NotificationStamp?, location: StoredLocation,
                                       settings: SukunSettings, now: Date, authorized: Bool? = nil,
                                       fajrAlarmActive: Bool? = nil) -> Bool {
        stamp?.needsReschedule(location: location, settings: settings, now: now, authorized: authorized,
                               fajrAlarmActive: fajrAlarmActive) ?? true
    }
}

/// Who planned the reminders and when: shown in the in-app diagnostics, so testers can see that the widget
/// kept planning while the app was closed.
public struct RescheduleRecord: Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case app, widget, background, manual
    }

    public static let limit = 30

    public var date: Date
    public var source: Source
    public var place: String?
    public var count: Int

    public init(date: Date, source: Source, place: String?, count: Int) {
        self.date = date
        self.source = source
        self.place = place
        self.count = count
    }
}
