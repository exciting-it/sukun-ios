import SukunKit
import SwiftUI
import UserNotifications

/// Debug and TestFlight builds: what iOS has scheduled for Sukun right now (iOS itself has no screen for this),
/// and who planned it when. The log shows widget runs even after opening the app, which only plans again when needed.
struct PendingRemindersView: View {
    @Environment(AppModel.self) private var model
    @State private var requests: [UNNotificationRequest] = []
    @State private var stamp: NotificationStamp?
    @State private var log: [RescheduleRecord] = []
    @State private var diagnosticNotifications = SharedStore.shared.diagnosticNotifications
    @State private var alarmCount = 0
    @State private var testAlarmNote: String?

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
                        await NotificationScheduler.reschedule(settings: model.settings, location: model.location,
                                                               source: .manual)
                        await load()
                    }
                }
            } footer: {
                Text(verbatim: "Times in this device’s time zone. The app, background refresh and widgets replace this list when place, settings or the remaining days change.")
            }

            Section {
                Toggle(String("Notify me when the widget plans"), isOn: $diagnosticNotifications)
                    .onChange(of: diagnosticNotifications) { _, on in SharedStore.shared.diagnosticNotifications = on }
                ForEach(Array(log.enumerated()), id: \.offset) { _, record in
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: record.source.rawValue.capitalized)
                            .font(.body.weight(record.source == .widget ? .semibold : .regular))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(verbatim: record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.monospacedDigit())
                            Text(verbatim: "\(record.count) · \(record.place ?? "no name")")
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                }
            } header: {
                Text(verbatim: "Who planned when")
            } footer: {
                Text(verbatim: "Newest first. Opening the app plans again only when the place, settings or permission changed, or fewer than 3 days are left, so earlier widget runs stay visible. The notification arrives quietly in Notification Center, no need to open the app.")
            }

            if FajrAlarms.isSupported {
                Section {
                    LabeledContent(String("Fajr alarms scheduled"), value: "\(alarmCount)")
                    LabeledContent(String("Alarm permission"),
                                   value: FajrAlarms.isAuthorized ? "allowed" : (FajrAlarms.isDenied ? "denied" : "not asked"))
                    Button(String("Ring a test alarm in 1 minute")) {
                        Task {
                            let ok = await FajrAlarms.scheduleTest(in: 60)
                            testAlarmNote = ok ? "Rings in about a minute. Lock the phone and wait." : "Couldn’t schedule (permission?)."
                            await load()
                        }
                    }
                    if let testAlarmNote {
                        Text(verbatim: testAlarmNote).font(.caption).foregroundStyle(Palette.secondaryText)
                    }
                } header: {
                    Text(verbatim: "Fajr alarm")
                }
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
        .navigationTitle(Text(verbatim: "Diagnostics"))
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
        log = SharedStore.shared.rescheduleLog
        alarmCount = FajrAlarms.scheduledCount
    }
}
