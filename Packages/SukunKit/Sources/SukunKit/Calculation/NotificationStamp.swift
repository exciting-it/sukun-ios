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

    /// Plan again when fewer than this many seconds of reminders are left.
    public static let minimumLead: TimeInterval = 3 * 86_400

    public init(location: StoredLocation, settings: SukunSettings, plan: [PlannedNotification]) {
        coordinate = location.coordinate
        timeZoneIdentifier = location.timeZoneIdentifier
        name = location.name
        countryCode = location.countryCode
        self.settings = settings
        plannedUntil = plan.last { $0.content != .openApp }?.fireDate
    }

    public func needsReschedule(location: StoredLocation, settings: SukunSettings, now: Date) -> Bool {
        if settings != self.settings { return true }
        if location.timeZoneIdentifier != timeZoneIdentifier || location.name != name
            || location.countryCode != countryCode { return true }
        if location.coordinate.distanceKilometers(to: coordinate) > 1 { return true }
        if let plannedUntil, plannedUntil.timeIntervalSince(now) < Self.minimumLead { return true }
        return false
    }

    public static func needsReschedule(_ stamp: NotificationStamp?, location: StoredLocation,
                                       settings: SukunSettings, now: Date) -> Bool {
        stamp?.needsReschedule(location: location, settings: settings, now: now) ?? true
    }
}
