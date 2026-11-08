import SukunKit
import SwiftUI
import WidgetKit

/// Small: static arrow pointing to the Qibla relative to north.
struct QiblaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.sukun.widget.qibla", provider: PrayerTimelineProvider()) { entry in
            QiblaWidgetView(entry: entry)
        }
        .configurationDisplayName("Qibla")
        .description("Direction of the Kaaba from your location, relative to north.")
        .supportedFamilies([.systemSmall])
    }
}

struct QiblaWidgetView: View {
    let entry: PrayerEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                VStack(spacing: 6) {
                    QiblaArrowDial(bearing: snapshot.qiblaBearing)
                        .padding(.horizontal, 10)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(snapshot.qiblaBearing.rounded()))°")
                            .font(.system(.title3, design: .rounded, weight: .light).monospacedDigit())
                            .foregroundStyle(Palette.text)
                        Text(snapshot.qiblaCompassPoint.abbreviation)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.accentText)
                            .widgetAccentable()
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Qibla direction \(Int(snapshot.qiblaBearing.rounded())) degrees, \(snapshot.qiblaCompassPoint.localizedName)"))
            } else {
                WidgetSetupView()
            }
        }
        .sukunWidgetBackground(entry.snapshot)
        .widgetURL(URL(string: "sukun://qibla"))
    }
}

#Preview(as: .systemSmall) {
    QiblaWidget()
} timeline: {
    PrayerEntry.preview
}
