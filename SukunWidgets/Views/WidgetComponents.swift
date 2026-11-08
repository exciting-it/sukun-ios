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

/// Marks the next prayer. Full color: a soft fill. Tinted / vibrant rendering keeps only alpha, where a fill
/// would turn into a bright slab under same-colored text, so it becomes a hairline outline instead.
struct NextHighlight: View {
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

/// Small-caps name + light numerals for one prayer.
struct PrayerTimeStack: View {
    let slot: PrayerSlot
    let formatter: PrayerTimeFormatter
    let isNext: Bool
    var compact = false

    var body: some View {
        VStack(spacing: 4) {
            Text(slot.kind.localizedName)
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isNext ? Palette.accentText : Palette.secondaryText)
            Text(formatter.numerals(from: slot.date))
                .font(.system(size: compact ? 15 : 17, weight: isNext ? .regular : .light, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Palette.text)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            if isNext { NextHighlight(cornerRadius: 14) }
        }
        .widgetAccentable(isNext)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isNext
            ? Text("\(slot.kind.localizedName), \(formatter.string(from: slot.date)), next prayer")
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
        .accessibilityHidden(true)
    }
}
