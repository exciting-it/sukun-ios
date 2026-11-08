import SukunKit
import SwiftUI
import WidgetKit

/// Background used by every system widget (removed automatically in tinted / vibrant rendering).
struct WidgetBackground: View {
    let period: DayPeriod
    var body: some View {
        LinearGradient(colors: [period.gradientTop, Palette.background], startPoint: .top, endPoint: .bottom)
    }
}

extension View {
    func sukunWidgetBackground(_ snapshot: PrayerSnapshot?) -> some View {
        containerBackground(for: .widget) {
            WidgetBackground(period: snapshot?.period ?? .midday)
        }
    }
}

/// Marks the current prayer. Full color: a soft fill. Tinted / vibrant rendering keeps only alpha, where a fill
/// would turn into a bright slab under same-colored text, so it becomes a hairline outline instead.
struct CurrentHighlight: View {
    var cornerRadius: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if renderingMode == .fullColor {
            shape.fill(Palette.highlight)
        } else {
            shape.strokeBorder(.white.opacity(0.45), lineWidth: 1)
        }
    }
}

/// Shown until the app has a location.
struct WidgetSetupView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "location")
                .font(.title3)
                .foregroundStyle(Palette.accentText)
                .widgetAccentable()
            Text("Open Sukun to set your location")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

/// "Maghrib in 1:52:10": the small hint to the next boundary under the current prayer.
/// Without a running prayer the featured name above already says what's coming, so the hint is just
/// "in 1:52:10"; pass `alwaysNamed` where no name is shown above it.
///
/// With the display off (Always-On, `isLuminanceReduced`) iOS updates widgets rarely and writes timers out as
/// "6 hours, 14 minutes", which doesn't fit. Then it shows the clock time instead: "Fajr 05:29".
struct UpcomingHint: View {
    let snapshot: PrayerSnapshot
    var alwaysNamed = false
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let named = snapshot.current != nil || alwaysNamed
        if isLuminanceReduced {
            if named {
                Text(verbatim: "\(snapshot.upcoming.kind.localizedName) \(snapshot.formatter.string(from: snapshot.upcoming.date))")
            }
            // Unnamed hint sits under the featured name and time, which already say it all.
        } else if named {
            Text("\(snapshot.upcoming.kind.localizedName) in \(Text(snapshot.upcoming.date, style: .timer))")
        } else {
            Text("in \(Text(snapshot.upcoming.date, style: .timer))")
        }
    }
}

/// Name + light numerals for one prayer.
struct PrayerTimeStack: View {
    let slot: PrayerSlot
    let formatter: PrayerTimeFormatter
    let isCurrent: Bool
    var isPast = false
    var compact = false

    var body: some View {
        VStack(spacing: 4) {
            Text(slot.kind.localizedName)
                .font(.system(size: compact ? 11 : 12, weight: isCurrent ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isCurrent ? Palette.text : Palette.secondaryText)
            Text(formatter.numerals(from: slot.date))
                .font(.system(size: compact ? 15 : 17, weight: isCurrent ? .regular : .light, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Palette.text)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if isCurrent { CurrentHighlight(cornerRadius: 14) }
        }
        .opacity(isPast ? 0.5 : 1)
        .widgetAccentable(isCurrent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCurrent
            ? Text("\(slot.kind.localizedName), \(formatter.string(from: slot.date)), current prayer")
            : Text("\(slot.kind.localizedName), \(formatter.string(from: slot.date))"))
    }
}

/// Static Qibla arrow relative to north (a widget can't read the compass).
struct QiblaArrowDial: View {
    let bearing: Double
    var lineWidth: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                Circle()
                    .stroke(Palette.divider, lineWidth: lineWidth)
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Palette.secondaryText.opacity(0.5))
                        .frame(width: 1, height: i == 0 ? 0 : 5)
                        .offset(y: -radius + 5)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
                Text(CompassPoint.north.abbreviation)
                    .font(.system(size: max(9, size * 0.11), weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .offset(y: -radius + max(8, size * 0.1))
                    .widgetAccentable()
                Image(systemName: "location.north.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.22, height: size * 0.32)
                    .foregroundStyle(Palette.accentText)
                    .offset(y: -size * 0.12)
                    .rotationEffect(.degrees(bearing))
                    .widgetAccentable()
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight) // geometry, never mirrored in RTL
        .accessibilityHidden(true)
    }
}

/// "Iftar in 3:21:10" during the fast, "Suhoor ends in 6:12:40" at night (Ramadan mode).
struct RamadanLine: View {
    let state: RamadanState
    let formatter: PrayerTimeFormatter
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        // Display off: short clock time instead of a spelled-out timer (see UpcomingHint).
        switch (state.countdown, isLuminanceReduced) {
        case (.iftar(let date), false): Text("Iftar in \(Text(date, style: .timer))")
        case (.suhoorEnds(let date), false): Text("Suhoor ends in \(Text(date, style: .timer))")
        case (.iftar(let date), true): Text("Iftar \(formatter.string(from: date))")
        case (.suhoorEnds(let date), true): Text("Suhoor ends \(formatter.string(from: date))")
        }
    }
}
