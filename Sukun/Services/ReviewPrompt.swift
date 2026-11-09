import Foundation

/// When to ask for an App Store rating with Apple's dialog (iOS shows it at most three times a year and decides
/// whether it appears). Ask only people who know the app: opened on 7 different days, installed 14+ days ago,
/// at a calm moment (a prayer is running, Today is in front), once per version, and never soon after they
/// reported a problem. Widgets don't count as use. The "Rate Sukun" link in Settings is always there.
final class ReviewPrompt: @unchecked Sendable {
    static let shared = ReviewPrompt(defaults: .standard, calendar: .current)

    static let requiredDays = 7
    static let minimumAge: TimeInterval = 14 * 86_400
    static let quietAfterProblem: TimeInterval = 14 * 86_400

    private let defaults: UserDefaults
    private let calendar: Calendar

    private enum Key {
        static let firstUse = "sukun.review.firstUse"
        static let days = "sukun.review.days"
        static let askedVersion = "sukun.review.askedVersion"
        static let problem = "sukun.review.problemReport"
    }

    init(defaults: UserDefaults, calendar: Calendar) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var activeDayCount: Int { (defaults.stringArray(forKey: Key.days) ?? []).count }

    func recordActiveDay(_ date: Date) {
        if defaults.object(forKey: Key.firstUse) == nil { defaults.set(date, forKey: Key.firstUse) }
        var days = defaults.stringArray(forKey: Key.days) ?? []
        guard days.count < Self.requiredDays else { return } // enough is enough; keeps the list tiny
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let key = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        if !days.contains(key) {
            days.append(key)
            defaults.set(days, forKey: Key.days)
        }
    }

    func recordProblemReport(_ date: Date) { defaults.set(date, forKey: Key.problem) }

    func recordAsked(version: String) { defaults.set(version, forKey: Key.askedVersion) }

    func shouldAsk(now: Date, version: String, prayerIsRunning: Bool) -> Bool {
        guard prayerIsRunning,
              activeDayCount >= Self.requiredDays,
              let firstUse = defaults.object(forKey: Key.firstUse) as? Date,
              now.timeIntervalSince(firstUse) >= Self.minimumAge,
              defaults.string(forKey: Key.askedVersion) != version
        else { return false }
        if let problem = defaults.object(forKey: Key.problem) as? Date,
           now.timeIntervalSince(problem) < Self.quietAfterProblem { return false }
        return true
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
