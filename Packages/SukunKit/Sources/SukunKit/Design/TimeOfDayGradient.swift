#if canImport(SwiftUI)
import SwiftUI

public extension DayPeriod {
    /// Top color of the background gradient; the bottom always melts into `Palette.background`.
    var gradientTop: Color {
        switch self {
        case .dawn: Color.dynamic(light: 0xE8D2DB, dark: 0x3A2E48)       // rose / muted violet dawn
        case .morning: Color.dynamic(light: 0xF2E2C6, dark: 0x1C3A32)    // pale gold / teal green
        case .midday: Color.dynamic(light: 0xE1EBDD, dark: 0x1B3B2D)     // sage / green
        case .afternoon: Color.dynamic(light: 0xF0DDBF, dark: 0x2F3726)  // warm sand / olive
        case .dusk: Color.dynamic(light: 0xF0CDB2, dark: 0x4A302C)       // apricot / warm rust
        case .night: Color.dynamic(light: 0xD9DEE6, dark: 0x07130F)      // cool grey / near-black green
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
            // The time-of-day color fades into the background over the upper ~60 % of the screen.
            LinearGradient(
                stops: [
                    .init(color: period.gradientTop, location: 0),
                    .init(color: Palette.background, location: 0.6),
                ],
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
