import SukunKit
import SwiftUI
import WidgetKit

/// Small Home Screen widget + all Lock Screen accessories: the prayer whose time is running and a hint
/// to the next boundary. The kind id stays "next" so widgets people already placed keep working.
struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "faith.sukun.widget.next", provider: PrayerTimelineProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Current Prayer")
        .description("The prayer whose time is running, and when the next one begins.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct NextPrayerWidgetView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .accessoryCircular: CircularAccessory(snapshot: snapshot)
                case .accessoryRectangular: RectangularAccessory(snapshot: snapshot)
                case .accessoryInline: InlineAccessory(snapshot: snapshot)
                default: SmallNextPrayerView(snapshot: snapshot)
                }
            } else {
                switch family {
                case .accessoryInline: Text("Sukun")
                case .accessoryCircular, .accessoryRectangular:
                    Image(systemName: "location.slash").accessibilityLabel(Text("Location needed"))
                default: WidgetSetupView()
                }
            }
        }
        .sukunWidgetBackground(entry.snapshot)
        .widgetURL(URL(string: "sukun://today"))
    }
}

struct SmallNextPrayerView: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        let formatter = snapshot.formatter
        let headlineDate = snapshot.headlineDate
        let isRunning = snapshot.current != nil || snapshot.morning != nil
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.headlineSymbol)
                    .font(.subheadline)
                Text(verbatim: snapshot.shortHeadline)
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isRunning ? Palette.text : Palette.secondaryText)
            .widgetAccentable()

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatter.numerals(from: headlineDate))
                    .font(.system(size: 38, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.text)
                if let period = formatter.periodSymbol(for: headlineDate) {
                    Text(period)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            StatusLine(snapshot: snapshot)
            .font(.system(.footnote, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PrayerAccessibility.label(for: snapshot))
    }
}

/// Countdown ring from the last boundary to the upcoming one (Fajr's ring ends at sunrise).
struct CircularAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        let upcoming = snapshot.upcoming
        ProgressView(timerInterval: snapshot.intervalStart...upcoming.date, countsDown: false) {
            Text(upcoming.kind.localizedName)
        } currentValueLabel: {
            VStack(spacing: 0) {
                Image(systemName: upcoming.kind.symbolName)
                    .font(.system(size: 11))
                Text(snapshot.formatter.numerals(from: upcoming.date))
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .progressViewStyle(.circular)
        .widgetAccentable()
        .accessibilityLabel(Text("Next: \(upcoming.kind.localizedName) at \(snapshot.formatter.string(from: upcoming.date))"))
    }
}

struct RectangularAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.headlineSymbol)
                Text(verbatim: snapshot.shortHeadline)
            }
            .font(.system(.headline, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .widgetAccentable()
            Text(snapshot.formatter.string(from: snapshot.headlineDate))
                .font(.system(.body, design: .rounded).monospacedDigit())
            StatusLine(snapshot: snapshot)
            .font(.system(.caption, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PrayerAccessibility.label(for: snapshot))
    }
}

/// One line next to the Lock Screen clock: when the next boundary is.
struct InlineAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        let upcoming = snapshot.upcoming
        if let noPrayerLine = snapshot.noPrayerLine {
            Label { Text(verbatim: noPrayerLine) } icon: { Image(systemName: snapshot.headlineSymbol) }
        } else if let morning = snapshot.morning, morning.kind == .duha {
            Label {
                Text(verbatim: "\(morning.kind.title) · \(upcoming.kind.localizedName) \(snapshot.formatter.string(from: upcoming.date))")
            } icon: {
                Image(systemName: morning.kind.symbolName)
            }
        } else {
            Label {
                Text("\(upcoming.kind.localizedName) \(snapshot.formatter.string(from: upcoming.date))")
            } icon: {
                Image(systemName: upcoming.kind.symbolName)
            }
        }
    }
}

enum PrayerAccessibility {
    static func label(for snapshot: PrayerSnapshot) -> Text {
        if let morning = snapshot.morningAccessibilityText { return Text(verbatim: morning) }
        let formatter = snapshot.formatter
        let upcoming = snapshot.upcoming
        if let current = snapshot.current {
            return Text("Current prayer: \(current.kind.localizedName) since \(formatter.string(from: current.date)). Next: \(upcoming.kind.localizedName) at \(formatter.string(from: upcoming.date))")
        }
        return Text("Next prayer: \(upcoming.kind.localizedName) at \(formatter.string(from: upcoming.date))")
    }
}

#Preview("Small", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    PrayerEntry.preview
}

#Preview("Circular", as: .accessoryCircular) {
    NextPrayerWidget()
} timeline: {
    PrayerEntry.preview
}
