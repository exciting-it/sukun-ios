# Launch features: time adjustments, early & Jumu'ah reminders, Ramadan mode

Status: approved · 2026-11-08

## Intent

Sukun is a calm, private, offline prayer-times app built around widgets. Research into what annoys users
of prayer apps (see conversation of 2026-11-08) showed two things a 1.0 must not miss:

1. **"The times don't match my mosque."** The most common complaint and the most common reason to delete
   a prayer app. Mosques use different methods and add precautionary minutes. Sukun already lets people
   pick method, Asr convention and high-latitude rule, but cannot match a mosque timetable to the minute.
2. **Reminders people rely on.** A reminder *before* the prayer (to get ready, travel to the mosque) and a
   Friday reminder for Jumu'ah are standard in the category.

Plus one seasonal feature with large impact for little UI: **Ramadan mode**, where the existing Fajr and
Maghrib times become Suhoor end and Iftar, with countdowns, without the user configuring anything.

## Goals

- Per-prayer minute adjustments that apply everywhere (app, widgets, notifications) consistently.
- An optional "remind me N minutes before" for the prayers whose notifications are on.
- An optional Jumu'ah reminder on Fridays.
- Ramadan mode that turns on by itself during Ramadan, shows Suhoor/Iftar countdowns, and can be
  corrected when the local Ramadan start differs from the calendar.

## Non-goals

- Mosque timetables, iqama times or any online data source (decided: Sukun stays offline for 1.0).
- Adhan audio, hadith/verse of the day (decided: not now).
- An *Imsak* buffer before Fajr (some communities stop eating ~10 min before Fajr). Users can't model it with
  adjustments without moving Fajr itself; out of scope for 1.0.
- Per-location adjustment profiles.
- Changing how the five prayers are listed on Fridays (Dhuhr stays Dhuhr).

## Anti-goals (failure even if it "works")

- Anything that sends data off the device.
- Notification noise: more than one extra notification per prayer, or reminders the user didn't ask for.
- Widgets or notifications disagreeing with the app by even a minute.
- Settings that feel technical. Defaults must be right without opening Settings.

## Constraints

- iOS keeps at most 64 pending local notifications per app. Sukun currently uses up to 60 for a rolling
  window of up to 7 days, refreshed when the app becomes active and by a background refresh (≥ 12 h).
- Settings live in `SukunSettings` (App Group, shared with the widget). Decoding must stay tolerant:
  missing keys fall back to defaults so existing installs keep their settings.
- Hijri dates use Foundation's Umm al-Qura calendar (`HijriDate` in SukunKit).
- All user-visible strings in English and German (String Catalogs).
- Must keep working with Reduce Motion, Dynamic Type AX5, VoiceOver, tinted widgets.

## Design

### 1. Time adjustments

- New setting: `adjustments: [PrayerKind: Int]`, minutes, range **-30…+30**, for all six times
  (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha). Sunrise is included because it ends Fajr and some
  timetables shift it.
- Applied in the calculation core (`CalculationConfiguration.adhanParameters` → Adhan's
  `params.adjustments`), so every consumer gets adjusted times with no extra code.
- **UI:** Settings → Calculation → new row **"Adjust times"** (shows "Off" or e.g. "Isha +5, Fajr −2").
  It opens a screen with one row per time: name, today's resulting time, and a stepper (−/+ 1 min).
  A footer explains: *"Match your mosque's timetable. Applies to the app, widgets and reminders."*
  A **"Reset"** button sets all to 0.
- The Calculation footer ("In use: …") and the Today footer gain "· adjusted" when any value ≠ 0, so a
  person who forgets they adjusted can see why times differ.
- Adjustments are **global**, not per location (our call: simplest; travellers who adjusted for their home
  mosque see "· adjusted" and can reset).

### 2. Early reminder

- New setting: `earlyReminderMinutes: Int?` with choices **Off, 5, 10, 15, 20, 30** (default Off).
- Applies to every prayer whose notification is on. Content: title = prayer name,
  body = *"Maghrib in 15 min · 16:43"*. Same thread as the prayer notifications.
- UI: in Settings → Notifications, a picker row **"Remind me before"** under the per-prayer toggles,
  disabled while no prayer notification is on.

### 3. Jumu'ah reminder

- New setting: `jumuahReminder: JumuahReminder?` (default nil = Off). **The user chooses the kind**
  (decided 2026-11-08):
  - `beforeDhuhr(minutes)`: **30, 45, 60, 90 min** before Dhuhr; follows the season and time adjustments
    automatically. Default when turned on: 45 min before Dhuhr.
  - `fixedTime(hour, minute)`: a clock time on Friday in the location's time zone (e.g. 12:45 for a mosque
    whose khutbah starts at 13:00). A reminder at a fixed time is not affected by adjustments.
- Fires on Fridays only (Friday in the location's time zone). Content: title *"Jumu'ah"*, body
  *"Today · Dhuhr 12:02"*.
- Independent of the Dhuhr prayer notification toggle.
- UI: Settings → Notifications, row **"Jumu'ah reminder"** opening a small screen: a toggle, a segmented
  choice **"Before Dhuhr" / "At a set time"**, then either the minutes picker or a time picker.

### 4. Notification budget

Scheduling moves into a pure, testable planner in SukunKit (`NotificationPlan`), which returns the list
of notifications to schedule from (settings, location, now). The app's `NotificationScheduler` only turns
the plan into `UNNotificationRequest`s.

- Budget stays **60** requests. The planner fills chronologically: for each day, the prayer
  notification, its early reminder (if any), the Jumu'ah reminder on Fridays, and the Ramadan items below.
  It stops when the budget is reached, so the window shrinks gracefully (5 prayers + early reminders =
  10/day → 6 days), never exceeding 60.
- **One extra notification per prayer at most** (our call). When two reminders target the same prayer,
  the specific one wins and the early reminder for that prayer is dropped: on Fridays the Jumu'ah reminder
  replaces Dhuhr's early reminder; in Ramadan the Suhoor reminder replaces Fajr's early reminder.
  So a day has at most 2 notifications per enabled prayer (10/day with all five), and the window is
  sized from that.
- **Late reminders are skipped, not sent** (our call). If a reminder's own time has already passed (the app
  opens 10 min before Maghrib with a 15 min reminder), it is not scheduled; the prayer notification still is.

### 5. Ramadan mode

- New settings: `ramadanMode: RamadanMode` = **Automatic** (default) / On / Off, and
  `hijriAdjustmentDays: Int` in **-2…+2** (default 0). The adjustment shifts the displayed Hijri date
  everywhere and the Ramadan detection, because the local start of Ramadan often differs by a day from
  the Umm al-Qura calendar.
- **When it's active (Automatic):** from **Maghrib on the evening before 1 Ramadan** until **Maghrib on
  the last day of Ramadan** (the Islamic day starts at sunset, so the first night's Suhoor countdown is
  already shown). "On" forces it for testing or local practice; "Off" hides it.
- **What changes:**
  - Today hero: an extra line below the existing hint: between Fajr and Maghrib *"Iftar in 3:21:10"*,
    between Maghrib and Fajr *"Suhoor ends in 6:12:40"*. Same quiet style, accent color.
  - Prayer list: Fajr row shows a secondary label *"Suhoor ends"*, Maghrib row *"Iftar"*.
  - Header: Hijri date line shows *"Ramadan 14, 1448"* as it already does; no extra banner.
  - Widgets: medium and large show the Iftar/Suhoor countdown in place of the next-prayer hint (that's what
    people want to know in Ramadan); small and Lock Screen rectangular add it as their last line,
    replacing the next-prayer hint. Circular ring and inline stay as they are.
  - Notifications (only for prayers whose notifications are on): Fajr body *"Suhoor has ended · 05:12"*,
    Maghrib body *"Time for Iftar · 16:43"*.
  - New optional **"Suhoor reminder"** in Settings → Ramadan: Off / 15 / 30 / 45 / 60 min before Fajr.
    Stored default is **Off** (`suhoorReminderMinutes: Int? = nil`); when the user turns it on, 30 min is
    preselected (our call). It fires only while Ramadan mode is active, and it is **independent of the
    Fajr notification toggle**, like the Jumu'ah reminder: turning it on asks for notification permission
    if needed, and the scheduler must not exit early just because no prayer notification is on.
- **UI:** new Settings section **"Ramadan"** with: mode picker (Automatic / On / Off), Suhoor reminder
  picker, and **"Hijri date"** stepper (−2…+2) showing today's resulting Hijri date. Footer:
  *"Ramadan mode shows Suhoor and Iftar times. If Ramadan starts a day earlier or later where you live,
  adjust the Hijri date."*
- Widgets refresh at the mode boundaries: the timeline already has entries at every Maghrib, which is where
  the mode switches.

### 6. Data and migration

`SukunSettings` gains `adjustments`, `earlyReminderMinutes`, `jumuahReminder`, `ramadanMode`,
`suhoorReminderMinutes`, `hijriAdjustmentDays`. All optional on decode with the defaults above.
`PrayerTimeline` and `PrayerSnapshot` take the Hijri adjustment into account for Ramadan state.

## Testing

- SukunKit unit tests:
  - Adjustments shift exactly the chosen times by the chosen minutes (Munich fixture), and leave others.
  - Decoding old settings JSON yields defaults for all new fields.
  - `NotificationPlan`: count never exceeds 60; early reminders 15 min before; Jumu'ah only on Fridays in the
    location's time zone; past reminders skipped; Ramadan bodies and Suhoor reminder only inside the window.
  - Ramadan window boundaries for Ramadan 1448 (Umm al-Qura), with Hijri adjustment −1/0/+1.
- App: screenshots of Settings (new rows), Today in Ramadan (forced "On"), widgets via the render harness.

## Left to the builder

- Exact layout of the "Adjust times" screen and pickers within the existing Form style.
- Wording polish of German strings (keep sentence case, no em dashes).
- How `NotificationPlan` identifiers are formed (must stay unique and prefixed `sukun.`).
