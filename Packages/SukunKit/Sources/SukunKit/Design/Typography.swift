#if canImport(SwiftUI)
import SwiftUI

public extension Font {
    /// Large light rounded numerals for times. Pass a `@ScaledMetric` size so it follows Dynamic Type.
    static func sukunNumerals(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static let sukunTitle = Font.system(.title2, design: .rounded, weight: .regular)
    static let sukunBody = Font.system(.body, design: .rounded)
    static let sukunCallout = Font.system(.callout, design: .rounded)
    static let sukunTime = Font.system(.title3, design: .rounded, weight: .light).monospacedDigit()
    static let sukunLabel = Font.system(.caption, design: .rounded, weight: .semibold)
}

/// Small-caps style label: uppercase, tracked, quiet color.
public struct SmallCapsLabel: ViewModifier {
    var color: Color
    public func body(content: Content) -> some View {
        content
            .font(.sukunLabel)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

public extension View {
    func smallCaps(color: Color = Palette.secondaryText) -> some View {
        modifier(SmallCapsLabel(color: color))
    }

    /// Form / List rows on Sukun's surface color instead of the system grey (night blue in dark mode).
    func sukunRowBackground() -> some View {
        listRowBackground(Palette.surface)
    }

    /// Rounded card with a soft shadow (none in dark mode).
    func sukunCard(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Palette.cornerRadius, style: .continuous)
                    .fill(Palette.surface)
                    .shadow(color: Palette.shadow, radius: 18, x: 0, y: 8)
            )
    }
}

public extension Animation {
    /// The only motion Sukun uses: calm ease, or nothing when Reduce Motion is on.
    static func sukun(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.45)
    }

    static func sukunSpring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.12)
    }
}
#endif
