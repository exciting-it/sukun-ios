import Foundation

public enum AppGroup {
    /// Read from the `SukunAppGroup` Info.plist key so the identifier lives in one place (project.yml).
    public static var identifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "SukunAppGroup") as? String) ?? "group.faith.sukun"
    }
}

/// Single source of truth for settings and the last known location, shared by app and widget
/// through App Group `UserDefaults`.
public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore(defaults: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)

    public static let didChangeNotification = Notification.Name("SukunSharedStoreDidChange")

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let settings = "sukun.settings.v1"
        static let gpsLocation = "sukun.gpsLocation.v1"
        static let onboardingDone = "sukun.onboardingDone"
        static let notificationStamp = "sukun.notificationStamp.v1"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var settings: SukunSettings {
        get { read(SukunSettings.self, Key.settings) ?? SukunSettings() }
        set { write(newValue, Key.settings) }
    }

    /// Last location obtained from GPS (by the app or the widget).
    public var gpsLocation: StoredLocation? {
        get { read(StoredLocation.self, Key.gpsLocation) }
        set { write(newValue, Key.gpsLocation) }
    }

    /// What the pending notifications were planned for (see `NotificationStamp`).
    public var notificationStamp: NotificationStamp? {
        get { read(NotificationStamp.self, Key.notificationStamp) }
        set { write(newValue, Key.notificationStamp) }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    /// The location prayer times are calculated for: the manual override if enabled, otherwise the last GPS fix.
    public var effectiveLocation: StoredLocation? {
        let s = settings
        if s.useManualLocation, let manual = s.manualLocation { return manual }
        return gpsLocation ?? s.manualLocation
    }

    private func read<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
