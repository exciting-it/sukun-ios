import ActivityKit
import AlarmKit
import SukunKit
import SwiftUI
import WidgetKit

/// The Fajr alarm on the Lock Screen and in the Dynamic Island while it rings or is snoozed. AlarmKit needs this
/// for the snooze countdown; the ringing alert itself is drawn by iOS.
@available(iOS 26.1, *)
struct FajrAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SukunAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: PrayerKind.fajr.symbolName)
                    .font(.title2)
                    .foregroundStyle(Palette.accentText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: PrayerKind.fajr.localizedName)
                        .font(.system(.headline, design: .rounded))
                    if let fajr = context.attributes.metadata?.fajr {
                        Text(fajr, style: .time)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                AlarmStatus(state: context.state)
                    .font(.system(.title2, design: .rounded, weight: .light).monospacedDigit())
            }
            .padding(16)
            .widgetURL(URL(string: "sukun://fajr"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(verbatim: PrayerKind.fajr.localizedName) } icon: {
                        Image(systemName: PrayerKind.fajr.symbolName)
                    }
                    .font(.system(.headline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmStatus(state: context.state)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "alarm").foregroundStyle(Palette.accentText)
            } compactTrailing: {
                AlarmStatus(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "alarm").foregroundStyle(Palette.accentText)
            }
            .widgetURL(URL(string: "sukun://fajr"))
        }
    }
}

/// "Snoozed · 4:12" while snoozed, nothing extra while ringing.
@available(iOS 26.1, *)
private struct AlarmStatus: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(Text("Snoozed"))
        case .paused, .alert:
            Image(systemName: "alarm.fill")
        @unknown default:
            EmptyView()
        }
    }
}
