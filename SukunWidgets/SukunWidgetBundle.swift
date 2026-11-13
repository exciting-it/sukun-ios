import SwiftUI
import WidgetKit

@main
struct SukunWidgetBundle: WidgetBundle {
    init() {
        FajrAlarmIntents.register() // widgets plan alarms too (NotificationScheduler.refreshIfNeeded)
    }

    var body: some Widget {
        NextPrayerWidget()
        DayPrayersWidget()
        OverviewWidget()
        QiblaWidget()
        if #available(iOS 26.1, *) {
            FajrAlarmLiveActivity()
        }
    }
}
