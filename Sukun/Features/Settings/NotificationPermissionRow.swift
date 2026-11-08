import SwiftUI
import UIKit

/// Shown wherever a reminder can be turned on while notifications are denied: turning it on then snaps back,
/// and this row says why and where to fix it.
struct NotificationPermissionRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        if model.notificationStatus.isDenied {
            Button("Allow notifications in Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
        }
    }
}
