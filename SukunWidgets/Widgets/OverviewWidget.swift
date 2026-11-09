import SukunKit
import SwiftUI
import WidgetKit

/// Large: next prayer, the full day, Hijri date and Qibla bearing.
struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "faith.sukun.widget.overview", provider: PrayerTimelineProvider()) { entry in
            OverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Overview")
        .description("Prayer times, Hijri date and Qibla direction.")
        .supportedFamilies([.systemLarge])
    }
}

struct OverviewWidgetView: View {
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
        let formatter = snapshot.formatter
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.location.displayName)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Palette.secondaryText)
                    Text(snapshot.hijriDate)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: snapshot.headline)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(snapshot.current != nil || snapshot.morning != nil ? Palette.text : Palette.secondaryText)
                        .widgetAccentable()
                    StatusLine(snapshot: snapshot)
                    .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.secondaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .accessibilityElement(children: .combine)
            }

            // Prayer list (rows share the free height so the list fills the widget evenly)
            VStack(spacing: 0) {
                ForEach(snapshot.today.slots) { slot in
                    let isCurrent = snapshot.isCurrent(slot)
                    HStack {
                        Image(systemName: slot.kind.symbolName)
                            .font(.footnote)
                            .frame(width: 20)
                            .foregroundStyle(isCurrent ? Palette.text : Palette.secondaryText)
                        Text(slot.kind.localizedName)
                            .font(.system(.subheadline, design: .rounded, weight: isCurrent ? .semibold : .regular))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text(formatter.string(from: slot.date))
                            .font(.system(.body, design: .rounded, weight: .light).monospacedDigit())
                            .foregroundStyle(Palette.text)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxHeight: 44)
                    .background {
                        if isCurrent { CurrentHighlight(cornerRadius: 12) }
                    }
                    .opacity(snapshot.isPast(slot) ? 0.5 : 1)
                    .widgetAccentable(isCurrent)
                    .accessibilityElement(children: .combine)
                }
            }

            .frame(maxHeight: .infinity, alignment: .top)

            // Qibla footer
            HStack(spacing: 10) {
                QiblaArrowDial(bearing: snapshot.qiblaBearing)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Qibla")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Palette.secondaryText)
                    Text("\(Int(snapshot.qiblaBearing.rounded()))° \(snapshot.qiblaCompassPoint.abbreviation)")
                        .font(.system(.subheadline, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.text)
                }
                Spacer()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Qibla direction \(Int(snapshot.qiblaBearing.rounded())) degrees, \(snapshot.qiblaCompassPoint.localizedName)"))
        }
    }
}

#Preview(as: .systemLarge) {
    OverviewWidget()
} timeline: {
    PrayerEntry.preview
}
