import SukunKit
import SwiftUI
import UIKit
import WidgetKit
import CoreLocation

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showingCitySearch = false
    @State private var showingFeedback = false
    /// The app may use the location, but the user declined it for widgets while having some placed.
    @State private var widgetsLackLocation = false
    @State private var showsDiagnostics = false
    /// The user turned the Fajr alarm on but alarms aren't allowed in iOS Settings.
    @State private var alarmsDenied = false
    private let feedbackConfig = FeedbackConfig.production

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if widgetsLackLocation && !model.isLocationDenied {
                        widgetLocationCard
                    }
                    morningSection
                    locationSection
                    calculationSection
                    notificationSection
                    fajrAlarmSection
                    ramadanSection
                    displaySection
                    feedbackSection
                    aboutSection
                    #if DEBUG
                    designPreviewSection
                    #endif
                    if showsDiagnostics {
                        diagnosticsSection
                    }
                }
                .sukunRowBackground()
            }
            .scrollContentBackground(.hidden)
            // The first group has no header, so give it room below the large title.
            .contentMargins(.top, 16, for: .scrollContent)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCitySearch) { CitySearchView() }
            .sheet(isPresented: $showingFeedback) { FeedbackView() }
            .task {
                await model.refreshNotificationStatus()
                showsDiagnostics = await Diagnostics.isAvailable()
            }
            .task(id: model.settings.useManualLocation) { await checkWidgetLocation() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task { await checkWidgetLocation() } // back from iOS Settings: hide the card once fixed
            }
        }
    }

    // MARK: Widget location

    /// First thing in Settings while it applies: without it, widgets and reminders stay on the last place when
    /// travelling. Calm, but impossible to miss.
    private var widgetLocationCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Widgets can’t follow you")
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                } icon: {
                    Image(systemName: "location.slash")
                        .foregroundStyle(Palette.accentText)
                }
                Text("When you travel, your widgets and reminders stay on your last place. In iOS Settings, choose Location → “While Using the App or Widgets”.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Open iOS Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentText)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Morning

    /// First on purpose: many people don't know these times exist, so the switch should be seen right away.
    private var morningSection: some View {
        Section {
            Toggle("Duha and no-prayer times", isOn: model.binding(\.showsMorningPeriods))
        } footer: {
            Text("Shows the Duha time in the morning and the short times at sunrise and before Dhuhr when one doesn’t pray.")
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
                Button("Allow location access in iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Your location never leaves this device.")
        }
    }

    /// Only relevant with the device location in use: a chosen city is meant to stay put.
    private func checkWidgetLocation() async {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "SukunForceWidgetHint") { // -SukunForceWidgetHint YES (screenshots)
            widgetsLackLocation = true
            return
        }
        #endif
        guard !model.settings.useManualLocation, model.locationService.isAuthorized else {
            widgetsLackLocation = false
            return
        }
        let hasWidgets = await withCheckedContinuation { (done: CheckedContinuation<Bool, Never>) in
            WidgetCenter.shared.getCurrentConfigurations { result in
                done.resume(returning: !((try? result.get()) ?? []).isEmpty)
            }
        }
        widgetsLackLocation = hasWidgets && !CLLocationManager().isAuthorizedForWidgetUpdates
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

            NavigationLink {
                AdjustTimesView()
            } label: {
                LabeledContent("Adjust times") {
                    if let summary = AdjustmentSummary.text(model.settings.adjustments) {
                        Text(summary)
                    } else {
                        Text("Off")
                    }
                }
            }
        } header: {
            Text("Calculation")
        } footer: {
            if let location = model.location {
                let resolved = CalculationConfiguration(settings: model.settings, location: location)
                Text("In use: \(resolved.method.localizedName) · \(resolved.madhab.localizedName) · \(resolved.highLatitude.localizedName)")
                    + (resolved.isAdjusted ? Text(" · adjusted") : Text(verbatim: ""))
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
                .accessibilityInputLabels(kind.voiceControlNames.map { Text(verbatim: $0) })
            }
            Picker("Remind me before", selection: Binding(
                get: { model.settings.earlyReminderMinutes },
                set: { value in Task { await model.setEarlyReminder(value) } }
            )) {
                Text("Off").tag(Int?.none)
                ForEach(ReminderChoices.early, id: \.self) { Text("\($0) min").tag(Int?.some($0)) }
            }
            .disabled(model.settings.notificationsEnabled.isEmpty)

            NavigationLink {
                JumuahReminderView()
            } label: {
                LabeledContent("Jumu'ah reminder") { Text(jumuahSummary) }
            }

            NotificationPermissionRow()
        } header: {
            Text("Notifications")
        } footer: {
            Text("A gentle local reminder at the start of each selected prayer. Nothing is sent over the internet.")
        }
    }

    // MARK: Fajr alarm (iOS 26.1+)

    @ViewBuilder
    private var fajrAlarmSection: some View {
        if FajrAlarms.isSupported {
            Section {
                Picker("Fajr alarm", selection: Binding(
                    get: { model.settings.fajrAlarmMinutesBefore },
                    set: { value in
                        Task {
                            let allowed = await model.setFajrAlarm(value)
                            alarmsDenied = !allowed
                        }
                    }
                )) {
                    Text("Off").tag(Int?.none)
                    ForEach(ReminderChoices.fajrAlarm, id: \.self) { minutes in
                        (minutes == 0 ? Text("At Fajr") : Text("\(minutes) min before")).tag(Int?.some(minutes))
                    }
                }
                if alarmsDenied || (model.settings.fajrAlarmMinutesBefore != nil && FajrAlarms.isDenied) {
                    Button("Allow alarms in iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } footer: {
                Text("A real alarm that wakes you for Fajr, even in silent mode, with a 5-minute snooze. It replaces the Fajr notification.")
            }
        }
    }

    private var jumuahSummary: String {
        switch model.settings.jumuahReminder {
        case nil: String(localized: "Off")
        case .beforeDhuhr(let minutes): String(localized: "\(minutes) min before Dhuhr")
        case .fixedTime(let hour, let minute):
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now)
                .map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
        }
    }

    // MARK: Ramadan

    private var ramadanSection: some View {
        Section {
            Picker("Ramadan mode", selection: model.binding(\.ramadanMode)) {
                ForEach(RamadanMode.allCases) { Text($0.localizedName).tag($0) }
            }
            Picker("Suhoor reminder", selection: Binding(
                get: { model.settings.suhoorReminderMinutes },
                set: { value in Task { await model.setSuhoorReminder(value) } }
            )) {
                Text("Off").tag(Int?.none)
                ForEach(ReminderChoices.suhoor, id: \.self) { Text("\($0) min before Fajr").tag(Int?.some($0)) }
            }
            .disabled(model.settings.ramadanMode == .off)
            Stepper(value: model.binding(\.hijriAdjustmentDays), in: ReminderChoices.hijriAdjustmentRange) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hijri date")
                    Text(HijriDate.string(for: .now, timeZone: model.location?.timeZone ?? .current,
                                          adjustmentDays: model.settings.hijriAdjustmentDays))
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        } header: {
            Text("Ramadan")
        } footer: {
            Text("Ramadan mode shows Suhoor and Iftar times. If Ramadan starts a day earlier or later where you live, adjust the Hijri date.")
        }
    }

    #if DEBUG
    // MARK: Design preview (debug builds only)

    private var designPreviewSection: some View {
        Section {
            Picker(selection: Binding(
                get: { model.designPreview },
                set: { model.setDesignPreview($0) }
            )) {
                Text(verbatim: "Live").tag(PrayerKind?.none)
                ForEach(PrayerKind.allCases) { Text($0.localizedName).tag(PrayerKind?.some($0)) }
            } label: {
                Text(verbatim: "Time of day")
            }
        } header: {
            Text(verbatim: "Design preview")
        } footer: {
            Text(verbatim: "Debug builds only. Today and Qibla show the app 10 minutes after the chosen time. Widgets and reminders are not affected.")
        }
    }
    #endif

    // MARK: Diagnostics (debug and TestFlight builds)

    private var diagnosticsSection: some View {
        Section {
            NavigationLink {
                PendingRemindersView()
            } label: {
                Text(verbatim: "Pending reminders")
            }
        } header: {
            Text(verbatim: "Diagnostics")
        } footer: {
            Text(verbatim: "Testers only (debug and TestFlight builds). Not shown in the App Store version.")
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

    // MARK: Feedback

    private var feedbackSection: some View {
        Section {
            Button("Send feedback") { showingFeedback = true }
            if let reviewURL = feedbackConfig.writeReviewURL {
                Button("Rate Sukun") { openURL(reviewURL) }
            }
        } header: {
            Text("Feedback")
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
