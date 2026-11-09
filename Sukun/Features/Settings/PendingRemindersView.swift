#if DEBUG
import SukunKit
import SwiftUI
import UserNotifications

/// Debug builds only: what iOS has scheduled for Sukun right now. iOS itself has no screen for this.
struct PendingRemindersView: View {
    @Environment(AppModel.self) private var model
    @State private var requests: [UNNotificationRequest] = []
    @State private var stamp: NotificationStamp?

    var body: some View {
        List {
            Section {
                LabeledContent(String("Pending"), value: "\(requests.count) / 64")
                LabeledContent(String("Planned for"), value: stampPlace)
                if let until = stamp?.plannedUntil {
                    LabeledContent(String("Last reminder"), value: until.formatted(date: .abbreviated, time: .shortened))
                }
                Button(String("Reschedule now")) {
                    Task {
                        await NotificationScheduler.reschedule(settings: model.settings, location: model.location)
                        await load()
                    }
                }
            } footer: {
                Text(verbatim: "Times in this device’s time zone. The app, background refresh and widgets replace this list when place, settings or the remaining days change.")
            }

            Section(String("Scheduled")) {
                if requests.isEmpty {
                    Text(verbatim: "Nothing scheduled. Turn on a reminder, and allow notifications.")
                        .foregroundStyle(Palette.secondaryText)
                }
                ForEach(requests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: fireDate(request)?.formatted(date: .abbreviated, time: .shortened) ?? "–")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.secondaryText)
                        Text(verbatim: request.content.title).font(.body.weight(.semibold))
                        if !request.content.subtitle.isEmpty {
                            Text(verbatim: request.content.subtitle).font(.caption)
                        }
                        Text(verbatim: request.content.body).font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: "Pending reminders"))
        .refreshable { await load() }
        .task { await load() }
    }

    private var stampPlace: String {
        guard let stamp else { return "–" }
        return [stamp.name ?? "no name", stamp.countryCode ?? "no country", stamp.timeZoneIdentifier].joined(separator: " · ")
    }

    private func fireDate(_ request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
    }

    private func load() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        requests = pending
            .filter { $0.identifier.hasPrefix("sukun.") }
            .sorted { (fireDate($0) ?? .distantFuture) < (fireDate($1) ?? .distantFuture) }
        stamp = SharedStore.shared.notificationStamp
    }
}
#endif
