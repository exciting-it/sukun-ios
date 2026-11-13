import AlarmKit
import AppIntents
import SukunKit

/// Stops a ringing or snoozed Fajr alarm (the "Stop" button in the Live Activity, and iOS's own stop) and plans
/// the coming days again. Only today's alarm ends: the alarm keeps waking the user every morning until they choose
/// "Notification" or "Off" in the app. Compiled into the app and the widget extension.
@available(iOS 26.1, *)
struct StopFajrAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Fajr alarm"
    static let isDiscoverable = false

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {}

    init(alarmID: UUID) {
        self.alarmID = alarmID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        await FajrAlarms.topUp()
        return .result()
    }
}

enum FajrAlarmIntents {
    /// Lets the kit attach the stop intent to every alarm it schedules.
    static func register() {
        if #available(iOS 26.1, *) {
            FajrAlarms.stopIntent = { StopFajrAlarmIntent(alarmID: $0) }
        }
    }
}
