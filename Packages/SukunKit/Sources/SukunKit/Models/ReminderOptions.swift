import Foundation

/// Friday reminder for Jumu'ah: relative to Dhuhr (follows the season and adjustments) or at a fixed clock
/// time in the location's time zone (for mosques with a fixed khutbah time).
public enum JumuahReminder: Codable, Hashable, Sendable {
    case beforeDhuhr(minutes: Int)
    case fixedTime(hour: Int, minute: Int)

    public static let beforeDhuhrChoices = [30, 45, 60, 90]
    public static let defaultReminder = JumuahReminder.beforeDhuhr(minutes: 45)

    /// Repairs stored values: unknown minutes fall back to the default, an impossible time disables it.
    func validated() -> JumuahReminder? {
        switch self {
        case .beforeDhuhr(let minutes):
            return Self.beforeDhuhrChoices.contains(minutes) ? self : Self.defaultReminder
        case .fixedTime(let hour, let minute):
            return (0...23).contains(hour) && (0...59).contains(minute) ? self : nil
        }
    }
}

/// Ramadan mode: on by itself during Ramadan (Automatic), forced on, or hidden.
public enum RamadanMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic, on, off

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .automatic: L10n.string("ramadan.automatic", default: "Automatic")
        case .on: L10n.string("ramadan.on", default: "On")
        case .off: L10n.string("ramadan.off", default: "Off")
        }
    }
}

/// The minute choices the UI offers; stored values outside these are treated as "off".
public enum ReminderChoices {
    public static let early = [5, 10, 15, 20, 30]
    public static let suhoor = [15, 30, 45, 60]
    public static let suhoorDefault = 30
    public static let adjustmentRange = -30...30
    public static let hijriAdjustmentRange = -2...2
}
