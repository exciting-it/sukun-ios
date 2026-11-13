import SukunKit
import SwiftUI

struct QiblaView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var headingService = HeadingService()
    /// Continuous (unwrapped) heading so the dial never spins the long way round at 359° → 0°.
    @State private var unwrappedHeading: Double = 0
    @State private var hasHeading = false
    @ScaledMetric(relativeTo: .largeTitle) private var bearingSize: CGFloat = 52

    private let alignmentTolerance = 3.0

    var body: some View {
        if let location = model.location {
            let bearing = QiblaCalculator.bearing(from: location.coordinate)
            let distance = QiblaCalculator.distanceKilometers(from: location.coordinate)
            let offset = headingService.heading.map { CompassAngle.delta(from: $0, to: bearing) }
            let isAligned = offset.map { abs($0) <= alignmentTolerance } ?? false

            ZStack {
                TimeOfDayBackground(period: model.snapshot(at: model.now())?.period ?? .midday)
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
                // The compass shouldn't move: no scrolling or bouncing unless large text needs it.
                .scrollBounceBehavior(.basedOnSize)
            }
            // A clear double tap ("success") the moment you face the Qibla; nothing when you turn away.
            .sensoryFeedback(trigger: isAligned) { _, aligned in
                aligned && model.settings.qiblaHaptics ? .success : nil
            }
            .onChange(of: isAligned) { _, aligned in
                // VoiceOver users hear it wherever focus is, not only while the readout is focused.
                if aligned {
                    AccessibilityNotification.Announcement(String(localized: "You are facing the Qibla.")).post()
                }
            }
            .onAppear {
                #if DEBUG
                if let offset = ScreenshotMode.fakeQiblaOffset {
                    headingService.simulatedHeading = (bearing - offset + 360).truncatingRemainder(dividingBy: 360)
                }
                #endif
                headingService.start()
            }
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
            // Direction + live guidance form one VoiceOver element: the label is the bearing, the value the guidance
            // ("Turn right 20°" … "You are facing the Qibla."), re-read while focused because it updates frequently.
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(bearing.rounded()))°")
                        .font(.sukunNumerals(bearingSize, weight: contrast == .increased ? .light : .thin))
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
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Qibla direction \(Int(bearing.rounded())) degrees, \(point.localizedName)"))
            .accessibilityValue(Text(statusText(offset: offset, isAligned: isAligned)))
            .accessibilityAddTraits(.updatesFrequently)

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
