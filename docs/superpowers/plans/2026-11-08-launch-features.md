# Launch Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per-prayer time adjustments, early / Jumu'ah / Suhoor reminders within the 60-notification budget, and an automatic Ramadan mode with Hijri correction.

**Architecture:** All rules live in SukunKit as pure, tested code: settings fields, adjustments inside `CalculationConfiguration` (so app, widgets and notifications agree), a `RamadanState` on `PrayerSnapshot`, and a `NotificationPlan` that decides what fires when. The app only renders: Settings screens, Today hero/list lines, widget lines, and `NotificationScheduler` turning plan items into `UNNotificationRequest`s with localized text.

**Tech Stack:** Swift 5 mode, SwiftUI (iOS 17+), WidgetKit, UserNotifications, Adhan 1.5 (`CalculationParameters.adjustments: PrayerAdjustments`), XCTest, XcodeGen, String Catalogs (en, de).

**Spec:** `docs/superpowers/specs/2026-11-08-launch-features-design.md`

## Global Constraints

- Adjustments: minutes **-30…+30**, all six times (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha), **global** (not per location).
- Early reminder choices: **Off, 5, 10, 15, 20, 30** min (default Off).
- Jumu'ah: default Off; `beforeDhuhr(minutes)` with **30, 45, 60, 90** (default when turned on: **45**) or `fixedTime(hour, minute)` on Friday in the **location's** time zone; fixed time ignores adjustments.
- Suhoor reminder: **Off, 15, 30, 45, 60** min before Fajr, stored default **nil**, **30** preselected when turned on; independent of the Fajr toggle; fires only while Ramadan mode is active.
- Ramadan mode: **Automatic** (default) / On / Off. Active from **Maghrib on the evening before 1 Ramadan** until **Maghrib on the last day**. Hijri correction **-2…+2** days (default 0), affects displayed Hijri date and detection.
- Notification budget **60**; **at most one extra notification per prayer** (Jumu'ah replaces Dhuhr's early reminder on Fridays; Suhoor replaces Fajr's early reminder); **late reminders are skipped**, the prayer notification is still scheduled. Identifiers prefixed `sukun.`.
- Settings decoding stays tolerant: missing/invalid keys → defaults; out-of-range numbers are clamped.
- Nothing leaves the device. All strings en + de, sentence case, no em dashes.
- Build must stay at 0 warnings, also with `SWIFT_STRICT_CONCURRENCY=complete`.

## Review Focus

1. **DST weeks:** a fixed Jumu'ah time (12:45) must stay 12:45 local on the Friday after a DST change; days are stepped with the location calendar, never `+86_400`. (Test in Task 4.)
2. **Traveller time zones:** "Friday" and "12:45" are the location's, not the device's (Mecca location, Berlin `now`). (Test in Task 4.)
3. **Out-of-range stored values** (e.g. adjustment 90, Hijri +5, early reminder 7) clamp or fall back instead of crashing or producing odd times. (Test in Task 1.)
4. **Ramadan boundary minutes:** one minute before/after Maghrib on the eve and on the last day, with Hijri correction −1/0/+1. (Test in Task 3.)
5. **Permission denied:** turning on an early/Jumu'ah/Suhoor reminder with notifications denied leaves the setting off and shows the existing "Allow notifications in Settings" row. (Test in Task 5.)

---

### Task 1: Settings model

**Files:**
- Modify: `Packages/SukunKit/Sources/SukunKit/Models/SukunSettings.swift`
- Create: `Packages/SukunKit/Sources/SukunKit/Models/ReminderOptions.swift`
- Test: `Packages/SukunKit/Tests/SukunKitTests/SettingsAndFormattingTests.swift`

**Interfaces:**
- Produces (in `ReminderOptions.swift`):
  - `public enum JumuahReminder: Codable, Hashable, Sendable { case beforeDhuhr(minutes: Int); case fixedTime(hour: Int, minute: Int) }` with `static let beforeDhuhrChoices = [30, 45, 60, 90]`, `static let defaultReminder = JumuahReminder.beforeDhuhr(minutes: 45)`.
  - `public enum RamadanMode: String, Codable, CaseIterable, Identifiable, Sendable { case automatic, on, off }` + `localizedName`.
  - `public enum ReminderChoices { static let early = [5, 10, 15, 20, 30]; static let suhoor = [15, 30, 45, 60]; static let suhoorDefault = 30 }`
- Produces (on `SukunSettings`): `adjustments: [PrayerKind: Int]` (default `[:]`), `earlyReminderMinutes: Int?`, `jumuahReminder: JumuahReminder?`, `ramadanMode: RamadanMode = .automatic`, `suhoorReminderMinutes: Int?`, `hijriAdjustmentDays: Int = 0`; helper `func adjustment(for: PrayerKind) -> Int`; `var hasAdjustments: Bool`.

- [ ] **Step 1: Write failing tests** `testNewSettingsDefaultFromOldJSON` (decode the JSON of the current encoder output without new keys → `adjustments == [:]`, `earlyReminderMinutes == nil`, `jumuahReminder == nil`, `ramadanMode == .automatic`, `suhoorReminderMinutes == nil`, `hijriAdjustmentDays == 0`), `testNewSettingsRoundTrip` (all fields set incl. `.fixedTime(hour: 12, minute: 45)` survive encode/decode), `testOutOfRangeValuesAreClamped` (JSON with `"adjustments":{"isha":90,"fajr":-45}`, `"hijriAdjustmentDays":5`, `"earlyReminderMinutes":7`, `"suhoorReminderMinutes":0` → isha 30, fajr -30, hijri 2, early nil, suhoor nil; unknown prayer key ignored).
- [ ] **Step 2: Run** `cd Packages/SukunKit && swift test --filter SettingsAndFormattingTests` → FAIL (members missing).
- [ ] **Step 3: Implement.** Encode `adjustments` as `[String: Int]` keyed by `PrayerKind.rawValue`, drop zeros on encode. Clamp on decode: adjustments to -30…30, Hijri to -2…2; early/suhoor minutes must be in their choice lists else nil; Jumu'ah `beforeDhuhr` minutes must be in choices else default, `fixedTime` hour 0…23 / minute 0…59 else nil. Add `RamadanMode.localizedName` strings to the SukunKit catalog (`ramadan.automatic` "Automatic" / "Automatisch", `ramadan.on` "On" / "An", `ramadan.off` "Off" / "Aus").
- [ ] **Step 4: Run** the same command → PASS.
- [ ] **Step 5: Commit** `feat(kit): settings for adjustments, reminders and Ramadan mode`

### Task 2: Adjustments in the calculation core

**Files:**
- Modify: `Packages/SukunKit/Sources/SukunKit/Calculation/CalculationConfiguration.swift`
- Test: `Packages/SukunKit/Tests/SukunKitTests/PrayerTimesTests.swift`

**Interfaces:**
- Consumes: `SukunSettings.adjustments` (Task 1).
- Produces: `CalculationConfiguration.adjustments: [PrayerKind: Int]` (filled by `init(settings:location:)`; memberwise init gets `adjustments: [PrayerKind: Int] = [:]`), applied in `adhanParameters` via `params.adjustments = PrayerAdjustments(fajr:sunrise:dhuhr:asr:maghrib:isha:)`. `var isAdjusted: Bool`.

- [ ] **Step 1: Failing test** `testAdjustmentsShiftOnlyChosenTimes`: Munich, MWL, 2026-12-15; schedule without adjustments vs with `[.isha: 5, .fajr: -2, .sunrise: 3]` → isha +300 s, fajr −120 s, sunrise +180 s, dhuhr/asr/maghrib unchanged (exact equality); `isAdjusted` true / false.
- [ ] **Step 2: Run** `swift test --filter PrayerTimesTests` → FAIL.
- [ ] **Step 3: Implement** as in Interfaces. (Adhan rounds to the minute after adjustment; compare via the existing schedule API.)
- [ ] **Step 4: Run** → PASS, and full `swift test` still green.
- [ ] **Step 5: Commit** `feat(kit): per-prayer minute adjustments`

### Task 3: Hijri correction and Ramadan state

**Files:**
- Modify: `Packages/SukunKit/Sources/SukunKit/Calculation/Formatting.swift` (`HijriDate`)
- Create: `Packages/SukunKit/Sources/SukunKit/Calculation/Ramadan.swift`
- Modify: `Packages/SukunKit/Sources/SukunKit/Calculation/PrayerSnapshot.swift`
- Test: create `Packages/SukunKit/Tests/SukunKitTests/RamadanTests.swift`

**Interfaces:**
- Produces:
  - `HijriDate.string(for:timeZone:adjustmentDays: Int = 0, locale:)` and `HijriDate.components(for:timeZone:adjustmentDays: Int = 0)` (shift the instant by whole days in the location calendar before converting).
  - `public enum Ramadan { static func isRamadanDay(_ date: Date, timeZone: TimeZone, adjustmentDays: Int) -> Bool }` (Hijri month 9 of that civil day).
  - `public struct RamadanState: Hashable, Sendable { enum Countdown: Hashable, Sendable { case iftar(Date), suhoorEnds(Date) }; let countdown: Countdown }`
  - `PrayerSnapshot.ramadan: RamadanState?` and `PrayerSnapshot.hijriDate` uses `settings.hijriAdjustmentDays`.
- Rule (spec): mode `.off` → nil; `.on` → always; `.automatic` → active iff the *Islamic day* is a Ramadan day, where the Islamic day of instant t is the civil day of t, or the next civil day once t ≥ that civil day's Maghrib. Countdown: if today's Fajr ≤ t < today's Maghrib → `.iftar(today's Maghrib)`, else `.suhoorEnds(next Fajr)`.

- [ ] **Step 1: Failing tests** (find 1 Ramadan 1448 and the last day with `Calendar(identifier: .islamicUmmAlQura)` in `Europe/Berlin`, Munich, settings MWL):
  - `testActivatesAtMaghribOnTheEve`: eve Maghrib −1 min → `ramadan == nil`; +1 min → `.suhoorEnds(first day's Fajr)`.
  - `testIftarCountdownDuringTheDay`: first day 12:00 → `.iftar(that day's Maghrib)`.
  - `testEndsAtMaghribOnTheLastDay`: last day Maghrib −1 min → `.iftar`; +1 min → nil.
  - `testHijriCorrectionShiftsTheWindow`: with `hijriAdjustmentDays = -1` the eve moves one day later; with `+1` one day earlier; `hijriDate` string differs by one day.
  - `testModeOnAndOff`: `.on` on a date in Rajab → non-nil; `.off` in Ramadan → nil.
- [ ] **Step 2: Run** `swift test --filter RamadanTests` → FAIL.
- [ ] **Step 3: Implement** per Interfaces.
- [ ] **Step 4: Run** → PASS; full `swift test` green.
- [ ] **Step 5: Commit** `feat(kit): Ramadan state and Hijri correction`

### Task 4: Notification plan

**Files:**
- Create: `Packages/SukunKit/Sources/SukunKit/Calculation/NotificationPlan.swift`
- Test: create `Packages/SukunKit/Tests/SukunKitTests/NotificationPlanTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3 (`PrayerCalculator` with adjustments, `Ramadan.isRamadanDay`).
- Produces:
  ```swift
  public struct PlannedNotification: Hashable, Sendable {
      public enum Content: Hashable, Sendable {
          case prayer(PrayerSlot, ramadan: RamadanVariant?)   // RamadanVariant: .suhoorEnded (Fajr), .iftar (Maghrib)
          case early(PrayerSlot, minutes: Int)
          case jumuah(dhuhr: PrayerSlot)
          case suhoor(fajr: PrayerSlot, minutes: Int)
      }
      public let id: String        // "sukun.<kind>.<prayer>.<epoch>"
      public let fireDate: Date
      public let content: Content
  }
  public enum NotificationPlan {
      public static let budget = 60
      public static func make(settings: SukunSettings, location: StoredLocation, now: Date, days: Int = 7) -> [PlannedNotification]
  }
  ```
- Rules: per civil day (location calendar) in chronological order: for each enabled prayer, its prayer notification and at most one extra (Fajr: Suhoor if Ramadan day and set, else early; Dhuhr on Friday: Jumu'ah if set, else early; others: early). Jumu'ah is planned even when Dhuhr's toggle is off; Suhoor even when Fajr's is off. "Ramadan day" for Fajr/Maghrib variants and Suhoor uses `Ramadan.isRamadanDay(fajr/maghrib civil day)` (or mode `.on`; never with `.off`). Skip items with `fireDate <= now`. Stop at `budget`. Sorted by `fireDate`.

- [ ] **Step 1: Failing tests:**
  - `testEarlyReminderFifteenMinutesBefore` (Isha on, early 15 → item at Isha −900 s, plus the prayer item).
  - `testNeverMoreThanSixty` (all five on, early 5, Jumu'ah, Ramadan On + Suhoor → `count <= 60`, and no prayer has two extra items).
  - `testJumuahOnlyOnFridaysInLocationTimeZone` (Mecca location, `now` = Thursday 23:30 Berlin, which is Friday 01:30 Riyadh → Jumu'ah item that same Riyadh Friday; no Jumu'ah on other days).
  - `testJumuahFixedTimeSurvivesDST` (Munich, `fixedTime(12, 45)`, window covering Fri 2026-10-23 and Fri 2026-10-30 → both at 12:45 Europe/Berlin).
  - `testJumuahReplacesDhuhrEarlyReminder`, `testSuhoorReplacesFajrEarlyReminder`.
  - `testLateReminderIsSkippedButPrayerKept` (`now` = Maghrib −10 min, early 15 → no early item for that Maghrib, prayer item present).
  - `testRamadanVariantsAndSuhoorOnlyInsideWindow` (Automatic, window around 1 Ramadan 1448: Fajr item on day 1 has `.suhoorEnded`, Maghrib `.iftar`, Suhoor item exists; on the eve's day none of these).
  - `testEmptyWhenNothingEnabled`.
- [ ] **Step 2: Run** `swift test --filter NotificationPlanTests` → FAIL.
- [ ] **Step 3: Implement** `make` per rules (step days with `Calendar.date(byAdding: .day…)` in the location calendar; fixed Jumu'ah via `calendar.date(bySettingHour:minute:second:of:)`).
- [ ] **Step 4: Run** → PASS; full `swift test` green.
- [ ] **Step 5: Commit** `feat(kit): notification plan with budget and reminder rules`

### Task 5: App scheduling, model and texts

**Files:**
- Modify: `Sukun/Services/NotificationScheduler.swift`, `Sukun/Services/AppModel.swift`, `Sukun/Resources/Localizable.xcstrings`
- Test: `SukunTests/AppModelTests.swift`, create `SukunTests/NotificationContentTests.swift`

**Interfaces:**
- Consumes: `NotificationPlan.make` (Task 4).
- Produces:
  - `enum NotificationText { static func content(for: PlannedNotification, formatter: PrayerTimeFormatter, placeName: String?) -> (title: String, body: String) }`. Copy (en / de):
    - prayer: title name; body "It’s time for %@ · %@" (existing)
    - prayer + suhoorEnded: "Suhoor has ended · %@" / "Suhoor ist vorbei · %@"
    - prayer + iftar: "Time for Iftar · %@" / "Zeit für Iftar · %@"
    - early: "%1$@ in %2$lld min · %3$@" / "%1$@ in %2$lld Min. · %3$@"
    - jumuah: title "Jumu'ah" / "Jumu'ah"; body "Today · Dhuhr %@" / "Heute · Dhuhr %@"
    - suhoor: title "Suhoor"; body "Suhoor ends in %lld min · Fajr %@" / "Suhoor endet in %lld Min. · Fajr %@"
  - `NotificationScheduler.reschedule` builds requests from the plan (calendar trigger or interval as now), no early exit on "no prayer enabled" — exits only if the plan is empty or permission missing.
  - `AppModel.setEarlyReminder(_ minutes: Int?) async`, `setJumuahReminder(_ reminder: JumuahReminder?) async`, `setSuhoorReminder(_ minutes: Int?) async`: when turning on, call `NotificationScheduler.requestAuthorization()` first; if denied, leave the setting unchanged (mirror `setNotification`).
- [ ] **Step 1: Failing tests:** `NotificationContentTests` (one assertion per copy line above, `en_US`, 24 h formatter), `AppModelTests.testReminderStaysOffWhenPermissionDenied` (inject an authorizer closure `requestAuthorization: () async -> Bool` into `AppModel` init with default `NotificationScheduler.requestAuthorization`; returning false → setting stays nil).
- [ ] **Step 2: Run** `xcodebuild … -scheme Sukun test -only-testing:SukunTests` → FAIL.
- [ ] **Step 3: Implement**, add de strings to the catalog.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(app): schedule reminders from the notification plan`

### Task 6: Settings UI

**Files:**
- Create: `Sukun/Features/Settings/AdjustTimesView.swift`, `Sukun/Features/Settings/JumuahReminderView.swift`
- Modify: `Sukun/Features/Settings/SettingsView.swift`, `Sukun/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: Task 1 settings, Task 5 `AppModel` setters, `model.binding(_:)`.
- UI (copy en / de, from spec):
  - Calculation section: row "Adjust times" / "Zeiten anpassen", value "Off"/"Aus" or a summary like "Isha +5, Fajr −2" (use U+2212 minus); footer "In use: …" gains " · adjusted" / " · angepasst" when `hasAdjustments`.
  - `AdjustTimesView`: one row per time (name, today's resulting time, `Stepper` −30…30 step 1 showing "+5 min"/"0"); footer "Match your mosque’s timetable. Applies to the app, widgets and reminders." / "Gleiche die Zeiten an deine Moschee an. Gilt für App, Widgets und Erinnerungen."; toolbar "Reset" / "Zurücksetzen".
  - Notifications section: picker "Remind me before" / "Vorher erinnern" (Off + `ReminderChoices.early`), disabled when no prayer toggle is on; row "Jumu'ah reminder" / "Jumu'ah-Erinnerung" → `JumuahReminderView` (Toggle; segmented "Before Dhuhr" / "Vor Dhuhr" and "At a set time" / "Zu fester Uhrzeit"; minutes picker or `DatePicker(.hourAndMinute)`).
  - New section "Ramadan": mode picker; Suhoor reminder picker (Off + choices, 30 preselected on turn-on); "Hijri date" / "Hidschri-Datum" stepper −2…+2 showing today's resulting Hijri date; footer "Ramadan mode shows Suhoor and Iftar times. If Ramadan starts a day earlier or later where you live, adjust the Hijri date." / "Der Ramadan-Modus zeigt Suhoor- und Iftar-Zeiten. Beginnt der Ramadan bei dir einen Tag früher oder später, passe das Hidschri-Datum an."
  - All rows use `.sukunRowBackground()`.
- [ ] **Step 1: Build** (`xcodebuild … build`) after implementing; 0 warnings.
- [ ] **Step 2: Screenshot check** in the simulator (light, dark, de, AX5) of Settings, Adjust times, Jumu'ah screen; fix truncation.
- [ ] **Step 3: Commit** `feat(app): settings for adjustments, reminders and Ramadan`

### Task 7: Today and widgets in Ramadan; adjusted hint

**Files:**
- Modify: `Sukun/Features/Today/TodayView.swift`, `Sukun/Features/Today/PrayerRow.swift`, `SukunWidgets/Views/WidgetComponents.swift`, `SukunWidgets/Widgets/*.swift`, both catalogs.

**Interfaces:**
- Consumes: `PrayerSnapshot.ramadan` (Task 3), `configuration.isAdjusted` (Task 2).
- Produces: `RamadanLine` view (app + widget copy each) rendering "Iftar in %@" / "Iftar in %@" and "Suhoor ends in %@" / "Suhoor endet in %@" with `Text(date, style: .timer)`, accent color.
- Placement (spec): Today hero gets `RamadanLine` below the hint; Fajr row secondary label "Suhoor ends" / "Suhoor endet", Maghrib "Iftar"; medium + large widgets show `RamadanLine` in place of `UpcomingHint`; small + rectangular replace their last line with it; circular + inline unchanged. Today footer: method name + " · adjusted" / " · angepasst" when adjusted.
- [ ] **Step 1: Failing test** in `SukunKitTests/RamadanTests`: `testSnapshotRamadanUsesAdjustedTimes` (Ramadan On, Maghrib +5 → `.iftar` date equals adjusted Maghrib).
- [ ] **Step 2: Implement** views; build 0 warnings.
- [ ] **Step 3: Visual check:** app with `ramadanMode = .on` (light/dark), widget render harness at 15:00 and 21:00 incl. tinted.
- [ ] **Step 4: Commit** `feat: Ramadan lines in Today and widgets, adjusted hint`

### Task 8: Docs and final verification

**Files:**
- Modify: `website/support/index.html`, `website/de/support/index.html` (mosque-times FAQ now points to "Settings, Calculation, Adjust times" / "Einstellungen, Berechnung, Zeiten anpassen"), `README.md` (Notifications section: plan, budget, reminder rules), `docs/APP_STORE_METADATA.md` (description bullets for adjustments, reminders, Ramadan; run `python3 docs/check_metadata.py`).
- [ ] **Step 1:** `swift test` in SukunKit and `xcodebuild -scheme Sukun test` with `SWIFT_STRICT_CONCURRENCY=complete` → all green, 0 warnings.
- [ ] **Step 2:** metadata check → all "ok".
- [ ] **Step 3: Commit** `docs: adjustments, reminders and Ramadan in support and store texts`
