import SukunKit
import SwiftUI
import UIKit

/// First screen when no location is known, and the fallback when location access is denied.
struct LocationSetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingSearch = false

    var body: some View {
        ZStack {
            TimeOfDayBackground(period: .dawn)
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 12) {
                    Text("Sukun")
                        .font(.system(.largeTitle, design: .rounded, weight: .light))
                        .foregroundStyle(Palette.text)
                    Text("Prayer times and Qibla. Calm, private, offline.")
                        .font(.sukunBody)
                        .foregroundStyle(Palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                VStack(spacing: 14) {
                    if model.isLocationDenied {
                        Text("Location access is off. Choose your city instead, or allow location access in Settings.")
                            .font(.sukunCallout)
                            .foregroundStyle(Palette.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(SukunSecondaryButtonStyle())
                    } else {
                        Text("Sukun uses your location only on this device to calculate prayer times and the Qibla direction.")
                            .font(.sukunCallout)
                            .foregroundStyle(Palette.secondaryText)
                            .multilineTextAlignment(.center)
                        Button {
                            model.useDeviceLocation()
                        } label: {
                            if model.isLocating {
                                ProgressView()
                            } else {
                                Label("Use my location", systemImage: "location")
                            }
                        }
                        .buttonStyle(SukunPrimaryButtonStyle())
                    }
                    Button("Choose a city") { showingSearch = true }
                        .buttonStyle(SukunSecondaryButtonStyle())
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 520)
        }
        .sheet(isPresented: $showingSearch) {
            CitySearchView()
        }
    }
}

struct SukunPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sukunBody.weight(.medium))
            .foregroundStyle(Palette.background)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Palette.text))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SukunSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sukunBody)
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().stroke(Palette.divider, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
