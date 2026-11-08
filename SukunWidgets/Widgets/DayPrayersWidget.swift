import SukunKit
import SwiftUI
import WidgetKit

/// Medium: the five prayers of the day, the next one highlighted.
struct DayPrayersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "faith.sukun.widget.day", provider: PrayerTimelineProvider()) { entry in
            DayPrayersWidgetView(entry: entry)
        }
        .configurationDisplayName("Today’s Prayers")
        .description("All five prayers at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct DayPrayersWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                WidgetSetupView()
            }
        }
        .sukunWidgetBackground(entry.snapshot)
        .widgetURL(URL(string: "sukun://today"))
    }

    private func content(_ snapshot: PrayerSnapshot) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.location.displayName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                Spacer()
                Text("\(snapshot.next.kind.localizedName) in \(Text(snapshot.next.date, style: .timer))")
                    .font(.system(.caption, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.accentText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(snapshot.displayDay.obligatory) { slot in
                    PrayerTimeStack(slot: slot, formatter: snapshot.formatter, isNext: snapshot.isNext(slot))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview(as: .systemMedium) {
    DayPrayersWidget()
} timeline: {
    PrayerEntry.preview
}
