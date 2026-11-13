import SukunKit
import SwiftUI
import UIKit

/// Fajr: off, a notification, or an alarm that wakes you (AlarmKit, iOS 26.1+). Opened from the Fajr row in Today,
/// from Settings, and from the alarm's Live Activity, so whoever wants to turn the alarm off lands right here.
/// Turning the alarm off is choosing "Notification" (or "Off"); there's no separate button.
struct FajrSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var minutes: Int = 20
    @State private var alarmDenied = false

    var body: some View {
        let current = model.fajrReminder
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: PrayerKind.fajr.localizedName)
                    .font(.sukunTitle.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)

                option(.off, title: Text("Off"), detail: nil, checked: current == .off)
                Divider()
                option(.notification, title: Text("Notification"), detail: Text("A calm reminder at Fajr"),
                       checked: current == .notification)
                Divider()
                option(.alarm(minutes: minutes), title: Text("Alarm"),
                       detail: Text("Rings even in silent mode, 5-minute snooze"), checked: isAlarm(current))

                if isAlarm(current) {
                    Picker("Alarm time", selection: $minutes) {
                        ForEach(ReminderChoices.fajrAlarm, id: \.self) { value in
                            (value == 0 ? Text("At Fajr") : Text("\(value) min")).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 30)
                    .padding(.top, 6)
                    .onChange(of: minutes) { _, value in
                        Task { await model.setFajrReminder(.alarm(minutes: value)) }
                    }
                    if let next = nextAlarmText {
                        next
                            .font(.sukunCallout.weight(.semibold))
                            .foregroundStyle(Palette.accentText)
                            .padding(.leading, 30)
                            .padding(.top, 10)
                    }
                    Text("The alarm replaces the Fajr notification. To turn it off, choose Notification or Off.")
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 30) // aligned with the option text, like the minutes and "Next alarm"
                        .padding(.top, 12)
                }

                if alarmDenied || model.fajrAlarmBlocked {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sukun isn’t allowed to set alarms. Allow it in iOS Settings, then choose Alarm.")
                            .font(.footnote)
                            .foregroundStyle(Palette.text)
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.surface.opacity(1))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let value = model.settings.fajrAlarmMinutesBefore { minutes = value }
        }
    }

    private func isAlarm(_ reminder: AppModel.FajrReminder) -> Bool {
        if case .alarm = reminder { return true }
        return false
    }

    private func option(_ choice: AppModel.FajrReminder, title: Text, detail: Text?, checked: Bool) -> some View {
        Button {
            Task {
                let allowed = await model.setFajrReminder(choice)
                if isAlarm(choice) { alarmDenied = !allowed }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.accentText)
                    .opacity(checked ? 1 : 0)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    title.font(.sukunBody).foregroundStyle(Palette.text)
                    if let detail {
                        detail.font(.footnote).foregroundStyle(Palette.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }

    /// "Next alarm: tomorrow 04:59" (today after midnight), in the location's time zone.
    private var nextAlarmText: Text? {
        guard FajrAlarms.isActive(model.settings), let location = model.location,
              let next = FajrAlarmPlan.next(settings: model.settings, location: location, now: Date()),
              let formatter = model.snapshot(at: Date())?.formatter else { return nil }
        let time = formatter.string(from: next.date)
        return FajrAlarmPlan.isToday(next.date, location: location, now: Date())
            ? Text("Next alarm: today \(time)")
            : Text("Next alarm: tomorrow \(time)")
    }
}
