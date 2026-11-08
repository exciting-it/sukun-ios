import SukunKit
import SwiftUI

/// Friday reminder: a number of minutes before Dhuhr, or a fixed time for mosques with a set khutbah.
struct JumuahReminderView: View {
    @Environment(AppModel.self) private var model

    private enum Kind: Hashable { case beforeDhuhr, fixedTime }

    var body: some View {
        let reminder = model.settings.jumuahReminder
        Form {
            Group {
                Section {
                    Toggle("Jumu'ah reminder", isOn: Binding(
                        get: { reminder != nil },
                        set: { on in Task { await model.setJumuahReminder(on ? .defaultReminder : nil) } }
                    ))
                    NotificationPermissionRow()
                } footer: {
                    Text("On Fridays. “Before Dhuhr” follows the season; a set time suits mosques with a fixed khutbah.")
                }

                if let reminder {
                    Section {
                        Picker("Reminder", selection: kindBinding(reminder)) {
                            Text("Before Dhuhr").tag(Kind.beforeDhuhr)
                            Text("At a set time").tag(Kind.fixedTime)
                        }
                        .pickerStyle(.segmented)

                        switch reminder {
                        case .beforeDhuhr(let minutes):
                            Picker("Minutes before Dhuhr", selection: Binding(
                                get: { minutes },
                                set: { value in model.update { $0.jumuahReminder = .beforeDhuhr(minutes: value) } }
                            )) {
                                ForEach(JumuahReminder.beforeDhuhrChoices, id: \.self) { Text("\($0) min").tag($0) }
                            }
                        case .fixedTime(let hour, let minute):
                            DatePicker("Time", selection: timeBinding(hour: hour, minute: minute),
                                       displayedComponents: .hourAndMinute)
                        }
                    }
                }
            }
            .sukunRowBackground()
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Jumu'ah")
        .task { await model.refreshNotificationStatus() }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kindBinding(_ reminder: JumuahReminder) -> Binding<Kind> {
        Binding(
            get: { if case .fixedTime = reminder { .fixedTime } else { .beforeDhuhr } },
            set: { kind in
                model.update {
                    $0.jumuahReminder = kind == .fixedTime ? .fixedTime(hour: 12, minute: 45) : .defaultReminder
                }
            }
        )
    }

    /// The picker edits a Date; only hour and minute are stored (interpreted in the location's time zone).
    private func timeBinding(hour: Int, minute: Int) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.update { $0.jumuahReminder = .fixedTime(hour: c.hour ?? 12, minute: c.minute ?? 45) }
            }
        )
    }
}
