import SukunKit
import SwiftUI
import WidgetKit

/// Small Home Screen widget + all Lock Screen accessories.
struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.sukun.widget.next", provider: PrayerTimelineProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("The upcoming prayer with a live countdown.")
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.next.kind.symbolName)
                    .font(.caption)
                Text("Next")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1)
            }
            .foregroundStyle(Palette.secondaryText)

            Spacer(minLength: 4)

            Text(snapshot.next.kind.localizedName)
                .font(.system(.headline, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.accentText)
                .widgetAccentable()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatter.numerals(from: snapshot.next.date))
                    .font(.system(size: 38, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.text)
                if let period = formatter.periodSymbol(for: snapshot.next.date) {
                    Text(period)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(snapshot.next.date, style: .timer)
                .font(.system(.footnote, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Next prayer: \(snapshot.next.kind.localizedName) at \(formatter.string(from: snapshot.next.date))"))
    }
}

/// Countdown ring from the previous boundary to the next prayer.
struct CircularAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        ProgressView(timerInterval: snapshot.previous.date...snapshot.next.date, countsDown: false) {
            Text(snapshot.next.kind.localizedName)
        } currentValueLabel: {
            VStack(spacing: 0) {
                Image(systemName: snapshot.next.kind.symbolName)
                    .font(.system(size: 11))
                Text(snapshot.formatter.numerals(from: snapshot.next.date))
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .progressViewStyle(.circular)
        .widgetAccentable()
        .accessibilityLabel(Text("Next prayer: \(snapshot.next.kind.localizedName) at \(snapshot.formatter.string(from: snapshot.next.date))"))
    }
}

struct RectangularAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.next.kind.symbolName)
                Text(snapshot.next.kind.localizedName)
            }
            .font(.system(.headline, design: .rounded))
            .widgetAccentable()
            Text(snapshot.formatter.string(from: snapshot.next.date))
                .font(.system(.body, design: .rounded).monospacedDigit())
            Text("in \(Text(snapshot.next.date, style: .timer))")
                .font(.system(.caption, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct InlineAccessory: View {
    let snapshot: PrayerSnapshot

    var body: some View {
        Label {
            Text("\(snapshot.next.kind.localizedName) \(snapshot.formatter.string(from: snapshot.next.date))")
        } icon: {
            Image(systemName: snapshot.next.kind.symbolName)
        }
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
