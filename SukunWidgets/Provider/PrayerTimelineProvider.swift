import SukunKit
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    /// nil when no location is known yet (user hasn't opened the app / granted access).
    let snapshot: PrayerSnapshot?

    static var preview: PrayerEntry {
        let location = StoredLocation(
            coordinate: Coordinate(latitude: 48.1351, longitude: 11.5820),
            name: String(localized: "Munich"),
            countryCode: "DE",
            timeZoneIdentifier: TimeZone.current.identifier,
            source: .gps
        )
        let now = Date()
        return PrayerEntry(date: now, snapshot: PrayerSnapshot(date: now, location: location, settings: SukunSettings()))
    }
}

/// One entry per prayer boundary (and local midnight) for the next 48 hours, so widgets flip exactly
/// at prayer times without extra reloads. Countdowns use `Text(.timer)` and need no entries of their own.
struct PrayerTimelineProvider: TimelineProvider {
    private static let horizonHours: Double = 48
    /// GPS users: re-check location every few hours to follow travel. Well within the daily reload budget.
    private static let gpsRefreshInterval: TimeInterval = 3 * 3600

    func placeholder(in context: Context) -> PrayerEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        if context.isPreview, SharedStore.shared.effectiveLocation == nil {
            completion(.preview)
            return
        }
        let store = SharedStore.shared
        let now = Date()
        let entry = store.effectiveLocation.map {
            PrayerEntry(date: now, snapshot: PrayerSnapshot(date: now, location: $0, settings: store.settings))
        } ?? PrayerEntry(date: now, snapshot: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        // WidgetKit's completion handler may be called from any thread; it's just not annotated @Sendable.
        nonisolated(unsafe) let completion = completion
        Task { @MainActor in
            let now = Date()
            let settings = SharedStore.shared.settings
            guard let location = await LocationResolver.resolveForWidget() else {
                let entry = PrayerEntry(date: now, snapshot: nil)
                completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600))))
                return
            }

            let entries = PrayerTimeline
                .snapshots(from: now, hours: Self.horizonHours, location: location, settings: settings)
                .map { PrayerEntry(date: $0.date, snapshot: $0) }

            guard let last = entries.last else {
                completion(Timeline(entries: [PrayerEntry(date: now, snapshot: nil)],
                                    policy: .after(now.addingTimeInterval(3600))))
                return
            }

            let reload = location.source == .gps
                ? min(last.date, now.addingTimeInterval(Self.gpsRefreshInterval))
                : last.date
            completion(Timeline(entries: entries, policy: .after(reload)))
        }
    }
}
