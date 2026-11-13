import StoreKit
import SukunKit
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 68
    @State private var showingLocationPicker = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    /// Counts returns to Today (tab switches) so the review check runs again then.
    @State private var visits = 0

    var body: some View {
        // Prayer times fall on whole minutes, so a per-minute timeline is enough to move the highlight.
        TimelineView(.everyMinute) { context in
            if let snapshot = model.snapshot(at: model.now(context.date)) {
                content(snapshot)
            } else {
                ContentUnavailableView("Prayer times unavailable", systemImage: "moon.zzz",
                                       description: Text("Times can’t be calculated for this location and date."))
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            CitySearchView()
        }
        .onAppear { visits += 1 }
        .task(id: "\(visits)-\(scenePhase == .active)") { await askForReviewIfDue() }
    }

    /// Apple's rating dialog, at a calm moment: Today has been in front for a few seconds, a prayer is running and
    /// nothing else is open. `ReviewPrompt` decides whether it's due at all (and iOS whether it really appears).
    private func askForReviewIfDue() async {
        guard scenePhase == .active else { return }
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled, scenePhase == .active, !showingLocationPicker, model.designPreview == nil else { return }
        let prompt = ReviewPrompt.shared
        let version = ReviewPrompt.appVersion
        let prayerIsRunning = model.snapshot(at: model.now())?.current != nil
        guard prompt.shouldAsk(now: Date(), version: version, prayerIsRunning: prayerIsRunning) else { return }
        prompt.recordAsked(version: version)
        requestReview()
    }

    private func content(_ snapshot: PrayerSnapshot) -> some View {
        ZStack {
            TimeOfDayBackground(period: snapshot.period)
            ScrollView {
                VStack(spacing: 32) {
                    header(snapshot)
                    FeaturedPrayerHero(snapshot: snapshot, numeralSize: heroSize)
                    PrayerListCard(snapshot: snapshot)
                    footer(snapshot)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // No rubber-banding when everything fits; scrolls (and bounces) only when it doesn't (large text).
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func header(_ snapshot: PrayerSnapshot) -> some View {
        VStack(spacing: 6) {
            Button {
                showingLocationPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.location.source == .gps ? "location.fill" : "mappin.and.ellipse")
                        .imageScale(.small)
                    Text(snapshot.location.displayName)
                }
                .smallCaps(color: Palette.secondaryText)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Location: \(snapshot.location.displayName)"))
            // Voice Control: "Tap Munich" (what's on screen) and "Tap Change location" both work.
            .accessibilityInputLabels([Text(verbatim: snapshot.location.displayName), Text("Change location")])
            .accessibilityHint(Text("Change location"))

            #if DEBUG
            if let preview = model.designPreview, !ScreenshotMode.isActive {
                Text(verbatim: "Design preview: \(preview.localizedName) + 10 min")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            #endif
            Text(snapshot.hijriDate)
                .font(.sukunCallout)
                .foregroundStyle(Palette.text)
            Text(CivilDate.string(for: snapshot.date, timeZone: snapshot.location.timeZone))
                .font(.sukunCallout)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func footer(_ snapshot: PrayerSnapshot) -> some View {
        (Text(snapshot.configuration.method.localizedName)
            + (snapshot.configuration.isAdjusted ? Text(" · adjusted") : Text(verbatim: "")))
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
    }
}

/// Big, quiet display of the prayer whose time is running, with a small hint to the next boundary.
/// Between sunrise and Dhuhr no prayer is running: it names the morning state instead (Sunrise, Duha,
/// Shortly before Dhuhr, or Morning), never Dhuhr as if it had begun.
struct FeaturedPrayerHero: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorSchemeContrast) private var contrast
    let snapshot: PrayerSnapshot
    let numeralSize: CGFloat

    var body: some View {
        let formatter = snapshot.formatter
        let headlineDate = snapshot.headlineDate
        let isRunning = snapshot.current != nil || snapshot.morning != nil
        VStack(spacing: 8) {
            Text(verbatim: snapshot.headline)
                .font(.sukunTitle)
                .foregroundStyle(isRunning ? Palette.text : Palette.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatter.numerals(from: headlineDate))
                    .font(.sukunNumerals(numeralSize, weight: contrast == .increased ? .light : .thin)) // thin strokes fail contrast; one step heavier with Increase Contrast
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let period = formatter.periodSymbol(for: headlineDate) {
                    Text(period)
                        .font(.sukunTitle)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            // In Ramadan the Suhoor/Iftar line often counts to the same instant (Fajr, Maghrib); show it once.
            let ramadanCoversHint = snapshot.ramadan?.countdown.date == snapshot.upcoming.date
            Group {
                if let noPrayerLine = snapshot.noPrayerLine {
                    Text(verbatim: noPrayerLine)
                } else if ramadanCoversHint {
                    EmptyView()
                } else if isRunning {
                    Text("\(snapshot.upcoming.kind.localizedName) in \(Text(model.realDate(snapshot.upcoming.date), style: .timer))")
                } else {
                    Text("in \(Text(model.realDate(snapshot.upcoming.date), style: .timer))")
                }
            }
            .font(.sukunBody.monospacedDigit())
            .foregroundStyle(Palette.secondaryText)

            if let ramadan = snapshot.ramadan {
                RamadanLine(state: ramadan)
                    .font(.sukunBody.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(formatter))
        .accessibilityValue(Text(model.realDate(snapshot.upcoming.date), style: .relative))
        .accessibilityHint(ramadanHint)
    }

    private var ramadanHint: Text {
        switch snapshot.ramadan?.countdown {
        case .iftar(let date): Text("Iftar in \(Text(model.realDate(date), style: .relative))")
        case .suhoorEnds(let date): Text("Suhoor ends in \(Text(model.realDate(date), style: .relative))")
        case nil: Text(verbatim: "")
        }
    }

    private func accessibilityLabel(_ formatter: PrayerTimeFormatter) -> Text {
        if let morning = snapshot.morningAccessibilityText { return Text(verbatim: morning) }
        let upcoming = snapshot.upcoming
        if let current = snapshot.current {
            return Text("Current prayer: \(current.kind.localizedName) since \(formatter.string(from: current.date)). Next: \(upcoming.kind.localizedName) at \(formatter.string(from: upcoming.date))")
        }
        return Text("Next prayer: \(upcoming.kind.localizedName) at \(formatter.string(from: upcoming.date))")
    }
}

struct PrayerListCard: View {
    @Environment(AppModel.self) private var model
    let snapshot: PrayerSnapshot

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 2) {
            ForEach(snapshot.today.slots) { slot in
                PrayerRow(
                    slot: slot,
                    isCurrent: snapshot.isCurrent(slot),
                    isPast: snapshot.isPast(slot),
                    formatter: snapshot.formatter,
                    notificationEnabled: model.settings.notificationsEnabled.contains(slot.kind),
                    onToggleNotification: toggleAction(for: slot.kind),
                    ramadanLabel: ramadanLabel(for: slot.kind),
                    onOpenFajr: slot.kind == .fajr && FajrAlarms.isSupported ? { model.showsFajrSheet = true } : nil,
                    alarmTime: slot.kind == .fajr ? nextAlarmTime : nil
                )
            }
        }
        .sukunCard(padding: 8)
        .sheet(isPresented: $model.showsFajrSheet) { FajrSheet() }
    }

    /// "04:59" while the Fajr alarm will really ring (on and allowed), else nil.
    private var nextAlarmTime: String? {
        guard FajrAlarms.isActive(model.settings), let location = model.location,
              let next = FajrAlarmPlan.next(settings: model.settings, location: location, now: Date()) else { return nil }
        return snapshot.formatter.numerals(from: next.date)
    }

    private func ramadanLabel(for kind: PrayerKind) -> LocalizedStringKey? {
        guard snapshot.isRamadanDay else { return nil }
        switch kind {
        case .fajr: return "Suhoor ends"
        case .maghrib: return "Iftar"
        default: return nil
        }
    }

    private func toggleAction(for kind: PrayerKind) -> ((Bool) -> Void)? {
        guard kind.isObligatory else { return nil }
        return { enabled in
            Task { await model.setNotification(enabled, for: kind) }
        }
    }
}

/// "Iftar in 3:21:10" during the fast, "Suhoor ends in 6:12:40" at night (Ramadan mode).
struct RamadanLine: View {
    @Environment(AppModel.self) private var model
    let state: RamadanState

    var body: some View {
        switch state.countdown {
        case .iftar(let date): Text("Iftar in \(Text(model.realDate(date), style: .timer))")
        case .suhoorEnds(let date): Text("Suhoor ends in \(Text(model.realDate(date), style: .timer))")
        }
    }
}
