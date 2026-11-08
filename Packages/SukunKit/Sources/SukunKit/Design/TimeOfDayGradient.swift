#if canImport(SwiftUI)
import SwiftUI

public extension DayPeriod {
    /// Top color of the background gradient; the bottom always melts into `Palette.background`.
    var gradientTop: Color {
        switch self {
        case .dawn: Color.dynamic(light: 0xEBDDE2, dark: 0x2B3050)       // soft rose / indigo dawn
        case .morning: Color.dynamic(light: 0xF3EADB, dark: 0x1C2E44)    // pale gold
        case .midday: Color.dynamic(light: 0xE9EFE7, dark: 0x1A3046)     // light sage
        case .afternoon: Color.dynamic(light: 0xF2E6D3, dark: 0x262C3A)  // warm sand
        case .dusk: Color.dynamic(light: 0xF0D9C6, dark: 0x3A2C34)       // apricot / plum
        case .night: Color.dynamic(light: 0xE2E5EA, dark: 0x08111C)      // cool / deep blue
        }
    }
}

/// Full-screen background: time-of-day gradient plus an optional, barely visible geometric pattern.
public struct TimeOfDayBackground: View {
    let period: DayPeriod
    let showsPattern: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(period: DayPeriod, showsPattern: Bool = true) {
        self.period = period
        self.showsPattern = showsPattern
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [period.gradientTop, Palette.background, Palette.background],
                startPoint: .top,
                endPoint: .bottom
            )
            if showsPattern {
                GeometricPattern(tile: 56)
                    .stroke(Palette.text, lineWidth: 0.5)
                    .opacity(0.045)
            }
        }
        .animation(.sukun(reduceMotion: reduceMotion), value: period)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif
