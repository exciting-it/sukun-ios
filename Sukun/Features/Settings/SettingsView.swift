import SukunKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingCitySearch = false

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                calculationSection
                notificationSection
                displaySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCitySearch) { CitySearchView() }
            .task { await model.refreshNotificationStatus() }
        }
    }

    // MARK: Location

    private var locationSection: some View {
        Section {
            if let location = model.location {
                LabeledContent {
                    location.source == .gps ? Text("Current location") : Text("Manual")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.displayName)
                        Text(StoredLocation.formatCoordinate(location.coordinate))
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
            }
            Button("Choose a city…") { showingCitySearch = true }
            if model.settings.useManualLocation {
                Button("Use current location") { model.useDeviceLocation() }
                    .disabled(model.isLocationDenied)
            }
            if model.isLocationDenied {
                Button("Allow location access in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Your location never leaves this device.")
        }
    }

    // MARK: Calculation

    private var calculationSection: some View {
        Section {
            Picker("Method", selection: model.binding(\.method)) {
                ForEach(CalculationMethodOption.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Asr time", selection: model.binding(\.madhab)) {
                ForEach(MadhabOption.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("High latitudes", selection: model.binding(\.highLatitude)) {
                ForEach(HighLatitudeOption.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.navigationLink)
        } header: {
            Text("Calculation")
        } footer: {
            if let location = model.location {
                let resolved = CalculationConfiguration(settings: model.settings, location: location)
                Text("In use: \(resolved.method.localizedName) · \(resolved.madhab.localizedName) · \(resolved.highLatitude.localizedName)")
            }
        }
    }

    // MARK: Notifications

    private var notificationSection: some View {
        Section {
            ForEach(PrayerKind.obligatory) { kind in
                Toggle(kind.localizedName, isOn: Binding(
                    get: { model.settings.notificationsEnabled.contains(kind) },
                    set: { enabled in Task { await model.setNotification(enabled, for: kind) } }
                ))
            }
            if model.notificationStatus.isDenied {
                Button("Allow notifications in Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("A gentle local reminder at the start of each selected prayer. Nothing is sent over the internet.")
        }
    }

    // MARK: Display

    private var displaySection: some View {
        Section("Display") {
            Picker("Time format", selection: model.binding(\.clockFormat)) {
                ForEach(ClockFormat.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            Toggle("Background pattern", isOn: model.binding(\.showsPattern))
            Toggle("Haptic feedback on Qibla", isOn: model.binding(\.qiblaHaptics))
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Sukun calculates everything on your device. No accounts, no tracking, no ads.")
        }
    }
}

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
