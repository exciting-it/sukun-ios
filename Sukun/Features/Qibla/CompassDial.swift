import SukunKit
import SwiftUI

/// A calm compass rose. `rotation` is applied to the whole dial (= -device heading), so north and the
/// Qibla marker keep their real-world direction while the fixed index at the top shows where the phone points.
struct CompassDial: View {
    let rotation: Double
    let qiblaBearing: Double
    let isAligned: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            ZStack {
                // Fixed index: where the top of the phone points.
                IndexMarker()
                    .fill(isAligned ? Palette.accent : Palette.text.opacity(0.5))
                    .frame(width: 14, height: 10)
                    .offset(y: -radius - 4)

                ZStack {
                    Circle()
                        .fill(Palette.surface)
                        .shadow(color: Palette.shadow, radius: 24, y: 10)
                    // Calm confirmation: the whole dial takes on a green wash while you face the Qibla.
                    Circle()
                        .fill(Palette.highlight)
                        .opacity(isAligned ? 1 : 0)
                        .animation(.sukun(reduceMotion: reduceMotion), value: isAligned)
                    Circle()
                        .stroke(Palette.divider, lineWidth: 1)

                    ForEach(0..<72, id: \.self) { tick in
                        let isMajor = tick % 6 == 0
                        Capsule()
                            .fill(isMajor ? Palette.text.opacity(0.45) : Palette.text.opacity(0.18))
                            .frame(width: isMajor ? 1.5 : 1, height: isMajor ? 12 : 6)
                            .offset(y: -radius + (isMajor ? 14 : 11))
                            .rotationEffect(.degrees(Double(tick) * 5))
                    }

                    ForEach(Cardinal.allCases, id: \.self) { cardinal in
                        Text(cardinal.label)
                            .font(.system(size: cardinal == .north ? 17 : 14, weight: cardinal == .north ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(cardinal == .north ? Palette.text : Palette.secondaryText)
                            .rotationEffect(.degrees(-(cardinal.degrees + rotation)))
                            .offset(y: -radius + 40)
                            .rotationEffect(.degrees(cardinal.degrees))
                    }

                    QiblaNeedle()
                        .fill(Palette.accent)
                        .frame(width: 18, height: radius - 52)
                        .offset(y: -(radius - 52) / 2)
                        .rotationEffect(.degrees(qiblaBearing))

                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 10, height: 10)
                }
                .rotationEffect(.degrees(rotation))
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        // A compass is geometry, not reading order: never mirror it in right-to-left languages.
        .environment(\.layoutDirection, .leftToRight)
    }

    enum Cardinal: CaseIterable {
        case north, east, south, west
        var degrees: Double {
            switch self {
            case .north: 0
            case .east: 90
            case .south: 180
            case .west: 270
            }
        }
        var label: String {
            switch self {
            case .north: CompassPoint.north.abbreviation
            case .east: CompassPoint.east.abbreviation
            case .south: CompassPoint.south.abbreviation
            case .west: CompassPoint.west.abbreviation
            }
        }
    }
}

/// Slim tapered needle pointing up.
struct QiblaNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY),
                       control: CGPoint(x: rect.midX + rect.width * 0.5, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.midX - rect.width * 0.5, y: rect.minY + rect.height * 0.25))
        p.closeSubpath()
        return p
    }
}

/// Small downward-pointing triangle above the dial.
struct IndexMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
