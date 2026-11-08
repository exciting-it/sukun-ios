import SukunKit
import SwiftUI

/// "Isha +5, Fajr −2": the summary shown next to "Adjust times". Uses a real minus sign (U+2212).
enum AdjustmentSummary {
    static func text(_ adjustments: [PrayerKind: Int]) -> String? {
        let parts = PrayerKind.allCases.compactMap { kind -> String? in
            guard let value = adjustments[kind], value != 0 else { return nil }
            return "\(kind.localizedName) \(signed(value))"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    static func signed(_ minutes: Int) -> String {
        minutes == 0 ? "0" : minutes > 0 ? "+\(minutes)" : "\u{2212}\(-minutes)"
    }
}

/// Per-time minute offsets to match a mosque timetable. Applies to the app, widgets and reminders.
struct AdjustTimesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                ForEach(PrayerKind.allCases) { kind in
                    Stepper(value: binding(for: kind), in: ReminderChoices.adjustmentRange) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.localizedName)
                                if let time = resultingTime(kind) {
                                    Text(time)
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(Palette.secondaryText)
                                }
                            }
                            Spacer()
                            Text("\(AdjustmentSummary.signed(model.settings.adjustment(for: kind))) min")
                                .monospacedDigit()
                                .foregroundStyle(model.settings.adjustment(for: kind) == 0 ? Palette.secondaryText : Palette.accentText)
                        }
                    }
                    .accessibilityValue(Text("\(AdjustmentSummary.signed(model.settings.adjustment(for: kind))) min"))
                    .accessibilityInputLabels(kind.voiceControlNames.map { Text(verbatim: $0) })
                }
            } footer: {
                Text("Match your mosque’s timetable. Applies to the app, widgets and reminders.")
            }
            .sukunRowBackground()
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Adjust times")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset") { model.update { $0.adjustments = [:] } }
                    .disabled(!model.settings.hasAdjustments)
            }
        }
    }

    private func binding(for kind: PrayerKind) -> Binding<Int> {
        Binding(
            get: { model.settings.adjustment(for: kind) },
            set: { value in model.update { $0.adjustments[kind] = value == 0 ? nil : value } }
        )
    }

    /// Today's time with the current adjustment applied.
    private func resultingTime(_ kind: PrayerKind) -> String? {
        guard let snapshot = model.snapshot(at: .now), let date = snapshot.today.time(for: kind) else { return nil }
        return snapshot.formatter.string(from: date)
    }
}
