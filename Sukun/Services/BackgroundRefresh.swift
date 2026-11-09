import BackgroundTasks
import SukunKit
import WidgetKit

/// Periodic background refresh that keeps the rolling notification window filled
/// even if the app isn't opened for a week.
enum BackgroundRefresh {
    static let identifier = "faith.sukun.ios.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func perform() async {
        schedule()
        let store = SharedStore.shared
        await NotificationScheduler.refreshIfNeeded(location: store.effectiveLocation, store: store, source: .background)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
