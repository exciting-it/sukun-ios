import SukunKit
import SwiftUI

struct QiblaView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headingService = HeadingService()
    /// Continuous (unwrapped) heading so the dial never spins the long way round at 359° → 0°.
    @State private var unwrappedHeading: Double = 0
    @State private var hasHeading = false

    private let alignmentTolerance = 3.0

    var body: some View {
        if let location = model.location {
            let bearing = QiblaCalculator.bearing(from: location.coordinate)
            let distance = QiblaCalculator.distanceKilometers(from: location.coordinate)
            let offset = headingService.heading.map { CompassAngle.delta(from: $0, to: bearing) }
            let isAligned = offset.map { abs($0) <= alignmentTolerance } ?? false

            ZStack {
                TimeOfDayBackground(period: model.snapshot(at: .now)?.period ?? .midday,
                                    showsPattern: model.settings.showsPattern)
                ScrollView {
                    VStack(spacing: 32) {
                        Text("Qibla")
                            .smallCaps()
                            .padding(.top, 24)

                        CompassDial(
                            rotation: hasHeading ? -unwrappedHeading : 0,
                            qiblaBearing: bearing,
                            isAligned: isAligned
                        )
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 24)
                        .accessibilityHidden(true)

                        readout(bearing: bearing, distance: distance, offset: offset, isAligned: isAligned)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: isAligned) { _, aligned in
                aligned && model.settings.qiblaHaptics
            }
            .onAppear { headingService.start() }
            .onDisappear { headingService.stop() }
            .onChange(of: headingService.heading) { _, newValue in
                guard let newValue else { return }
                if !hasHeading {
                    unwrappedHeading = newValue
                    hasHeading = true
                    return
                }
                let delta = CompassAngle.delta(from: unwrappedHeading, to: newValue)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    unwrappedHeading += delta
                }
            }
        }
    }

    @ViewBuilder
    private func readout(bearing: Double, distance: Double, offset: Double?, isAligned: Bool) -> some View {
        let point = CompassPoint(degrees: bearing)
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(bearing.rounded()))°")
                    .font(.sukunNumerals(52, weight: .thin))
                    .foregroundStyle(Palette.text)
                Text(point.abbreviation)
                    .font(.sukunTitle)
                    .foregroundStyle(Palette.secondaryText)
            }
            Text(statusText(offset: offset, isAligned: isAligned))
                .font(.sukunBody)
                .foregroundStyle(isAligned ? Palette.accentText : Palette.secondaryText)
                .multilineTextAlignment(.center)
                .animation(.sukun(reduceMotion: reduceMotion), value: isAligned)

            Text("\(distance.formatted(.number.precision(.fractionLength(0)))) km to the Kaaba")
                .font(.sukunCallout)
                .foregroundStyle(Palette.secondaryText)

            if headingService.needsCalibration {
                Label("Move your phone in a figure-eight to calibrate the compass.", systemImage: "infinity")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            } else if hasHeading && !headingService.usesTrueNorth {
                Text("Using magnetic north. Allow location access for higher accuracy.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Qibla direction \(Int(bearing.rounded())) degrees, \(point.localizedName)"))
    }

    private func statusText(offset: Double?, isAligned: Bool) -> LocalizedStringKey {
        guard headingService.isAvailable else {
            return "No compass on this device. Face the bearing above, measured clockwise from north."
        }
        guard let offset else { return "Hold your phone flat." }
        if isAligned { return "You are facing the Qibla." }
        let degrees = Int(abs(offset).rounded())
        return offset > 0 ? "Turn right \(degrees)°" : "Turn left \(degrees)°"
    }
}
