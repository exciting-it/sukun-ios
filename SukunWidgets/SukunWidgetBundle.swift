import SwiftUI
import WidgetKit

@main
struct SukunWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        DayPrayersWidget()
        OverviewWidget()
        QiblaWidget()
    }
}
