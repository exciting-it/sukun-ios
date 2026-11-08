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
                    NextPrayerHero(snapshot: snapshot, numeralSize: heroSize)
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
        Text(snapshot.configuration.method.localizedName)
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
    }
}

/// Big, quiet display of the next prayer with a live countdown.
struct NextPrayerHero: View {
    let snapshot: PrayerSnapshot
    let numeralSize: CGFloat

    var body: some View {
        let formatter = snapshot.formatter
        VStack(spacing: 8) {
            Text(snapshot.next.kind.localizedName)
                .smallCaps(color: Palette.accentText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatter.numerals(from: snapshot.next.date))
                    .font(.sukunNumerals(numeralSize, weight: .thin))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let period = formatter.periodSymbol(for: snapshot.next.date) {
                    Text(period)
                        .font(.sukunTitle)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            Text("in \(Text(snapshot.next.date, style: .timer))")
                .font(.sukunBody.monospacedDigit())
                .foregroundStyle(Palette.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Next prayer: \(snapshot.next.kind.localizedName) at \(formatter.string(from: snapshot.next.date))"))
        .accessibilityValue(Text(snapshot.next.date, style: .relative))
    }
}

struct PrayerListCard: View {
    @Environment(AppModel.self) private var model
    let snapshot: PrayerSnapshot

    var body: some View {
        let slots = snapshot.displayDay.slots
        VStack(spacing: 0) {
            if snapshot.isShowingTomorrow {
                Text("Tomorrow")
                    .smallCaps()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                PrayerRow(
                    slot: slot,
                    isNext: snapshot.isNext(slot),
                    isPast: slot.date <= snapshot.date,
                    formatter: snapshot.formatter,
                    notificationEnabled: model.settings.notificationsEnabled.contains(slot.kind),
                    onToggleNotification: toggleAction(for: slot.kind)
                )
                if index < slots.count - 1 {
                    Rectangle()
                        .fill(Palette.divider)
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)
                }
            }
        }
        .sukunCard(padding: 8)
    }

    private func toggleAction(for kind: PrayerKind) -> ((Bool) -> Void)? {
        guard kind.isObligatory else { return nil }
        return { enabled in
            Task { await model.setNotification(enabled, for: kind) }
        }
    }
}
