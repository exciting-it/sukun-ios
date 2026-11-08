import SukunKit
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 68
    @State private var showingLocationPicker = false

    var body: some View {
        // Prayer times fall on whole minutes, so a per-minute timeline is enough to move the highlight.
        TimelineView(.everyMinute) { context in
            if let snapshot = model.snapshot(at: context.date) {
                content(snapshot)
            } else {
                ContentUnavailableView("Prayer times unavailable", systemImage: "moon.zzz",
                                       description: Text("Times can’t be calculated for this location and date."))
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            CitySearchView()
        }
    }

    private func content(_ snapshot: PrayerSnapshot) -> some View {
        ZStack {
            TimeOfDayBackground(period: snapshot.period, showsPattern: model.settings.showsPattern)
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Location: \(snapshot.location.displayName)"))
            .accessibilityHint(Text("Change location"))

            Text(snapshot.hijriDate)
                .font(.sukunCallout)
                .foregroundStyle(Palette.text)
            Text(snapshot.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
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
/// Between sunrise and Dhuhr no prayer is running, so it features the upcoming Dhuhr instead.
struct FeaturedPrayerHero: View {
    let snapshot: PrayerSnapshot
    let numeralSize: CGFloat

    var body: some View {
        let formatter = snapshot.formatter
        let featured = snapshot.featured
        let isRunning = snapshot.current != nil
        VStack(spacing: 8) {
            Text(featured.kind.localizedName)
                .font(.sukunTitle)
                .foregroundStyle(isRunning ? Palette.accentText : Palette.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatter.numerals(from: featured.date))
                    .font(.sukunNumerals(numeralSize, weight: .thin))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let period = formatter.periodSymbol(for: featured.date) {
                    Text(period)
                        .font(.sukunTitle)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            // In Ramadan the Suhoor/Iftar line often counts to the same instant (Fajr, Maghrib); show it once.
            let ramadanCoversHint = snapshot.ramadan?.countdown.date == snapshot.upcoming.date
            Group {
                if ramadanCoversHint {
                    EmptyView()
                } else if isRunning {
                    Text("\(snapshot.upcoming.kind.localizedName) in \(Text(snapshot.upcoming.date, style: .timer))")
                } else {
                    Text("in \(Text(snapshot.upcoming.date, style: .timer))")
                }
            }
            .font(.sukunBody.monospacedDigit())
            .foregroundStyle(Palette.secondaryText)

            if let ramadan = snapshot.ramadan {
                RamadanLine(state: ramadan)
                    .font(.sukunBody.monospacedDigit())
                    .foregroundStyle(Palette.accentText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(formatter))
        .accessibilityValue(Text(snapshot.upcoming.date, style: .relative))
        .accessibilityHint(ramadanHint)
    }

    private var ramadanHint: Text {
        switch snapshot.ramadan?.countdown {
        case .iftar(let date): Text("Iftar in \(Text(date, style: .relative))")
        case .suhoorEnds(let date): Text("Suhoor ends in \(Text(date, style: .relative))")
        case nil: Text(verbatim: "")
        }
    }

    private func accessibilityLabel(_ formatter: PrayerTimeFormatter) -> Text {
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
        VStack(spacing: 2) {
            ForEach(snapshot.today.slots) { slot in
                PrayerRow(
                    slot: slot,
                    isCurrent: snapshot.isCurrent(slot),
                    isPast: snapshot.isPast(slot),
                    formatter: snapshot.formatter,
                    notificationEnabled: model.settings.notificationsEnabled.contains(slot.kind),
                    onToggleNotification: toggleAction(for: slot.kind),
                    ramadanLabel: ramadanLabel(for: slot.kind)
                )
            }
        }
        .sukunCard(padding: 8)
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
    let state: RamadanState

    var body: some View {
        switch state.countdown {
        case .iftar(let date): Text("Iftar in \(Text(date, style: .timer))")
        case .suhoorEnds(let date): Text("Suhoor ends in \(Text(date, style: .timer))")
        }
    }
}
