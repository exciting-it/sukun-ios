import SwiftUI
import WidgetKit

@main
struct SukunWidgetBundle: WidgetBundle {
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
