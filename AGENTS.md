# AGENTS.md: Sukun

Guide for AI coding agents (Claude Code, Codex, Cursor, Copilot, Gemini…) and new contributors.
Read it fully before changing anything. `README.md` has the setup details; this file explains the product,
the code map, and the decisions you must not undo by accident.

## 1. What Sukun is

A calm, private iPhone app for the five daily prayer times and the Qibla, built around Home Screen and
Lock Screen widgets. Name: "Sukun" (سكون, stillness). Domain sukun.faith.

- Bundle ID `faith.sukun.ios`, widget `faith.sukun.ios.widgets`, App Group `group.faith.sukun`, Team `5A57FGF7LP`.
- iOS 17+, iPhone only (`TARGETED_DEVICE_FAMILY: 1`, `UIRequiresFullScreen`), SwiftUI + WidgetKit.
- Version 1.0.0 (build 1), release in preparation (see `docs/APP_STORE_CHECKLIST.md`).
- Languages: English (source), German, Arabic (RTL).
- Paid app, 1.99 €, no in-app purchases, no subscription, no ads. The owner donates 50 % of proceeds to
  Islamic Relief projects; the App Store texts say so (keep them true).

**Principles (the product is these principles; don't trade them away for features):**
- **Calm:** neutral surfaces, one quiet green accent for signals only, thin numerals, little motion.
- **Offline and private:** all calculation on device (Adhan). No backend, no account, no analytics SDK,
  no tracking, no ads. Location never leaves the device. The only request of our own is the optional
  feedback form (see Section 3).
- **Accurate:** sensible regional defaults, everything overridable, times agree everywhere (app, widgets,
  notifications) because they come from one configuration.

## 2. Features

| Feature | Where | Notes |
|---|---|---|
| Today screen | `Sukun/Features/Today/` | Hero shows the **current** prayer (name + time) with a small hint "Next in hh:mm:ss". Prayer list with bells. Hijri + Gregorian date, location button, method name in the footer. |
| Morning periods | `MorningPeriod` (kit), hero, widgets | Between sunrise and Dhuhr the displays name the state, never Dhuhr as if running: **Sunrise** ("No prayer until S+15"), **Duha** ("Dhuhr in …"), **Shortly before Dhuhr** ("No prayer until D"); 15/10 min constants in `MorningPeriod`. Setting "Duha and no-prayer times" (first in Settings, default on); off → one neutral "Morning". List stays 6 rows. Widgets: no-prayer line beats the Ramadan line. Spec: `docs/superpowers/specs/2026-11-09-morning-periods-design.md`. |
| Current prayer logic | `PrayerSnapshot` | `current` = running obligatory prayer; **nil between sunrise and Dhuhr** (no prayer time); after midnight it is yesterday's Isha. `upcoming` = next boundary incl. sunrise. `featured` = what the hero shows. |
| Reminders | `NotificationPlan`, `NotificationScheduler`, `NotificationText`, `NotificationStamp` (all kit) | Local notifications only (no APNs). The **widget extension also reschedules** (`refreshIfNeeded`) because iOS keeps waking widgets after the app is swiped away; plan ends with a quiet "Open Sukun…" item. Settings shows a card at the very top when widgets are placed but lack location permission (`-SukunForceWidgetHint YES` forces it in debug). Debug and TestFlight builds (`Diagnostics.isAvailable`, StoreKit `AppTransaction` environment): Settings → Diagnostics → Pending reminders lists what iOS has scheduled, a log of who planned when (app/widget/background/manual), and an opt-in quiet notification whenever the widget plans. The app plans on launch only when needed (`refreshIfNeeded`); settings edits reschedule directly. Buttons that leave the app say "iOS Settings". Per prayer on/off, "remind me before" (early), Jumu'ah (before Dhuhr **or** fixed time, user chooses), Suhoor in Ramadan. |
| Adjust times | `AdjustTimesView`, `CalculationConfiguration` | −30…+30 min per time, applied in the calculation so all surfaces agree. |
| Ramadan mode | `Ramadan.swift`, Settings | Automatic/On/Off. Window: Maghrib on the eve of 1 Ramadan → Maghrib of the last day. Labels "Suhoor ends" (Fajr) / "Iftar" (Maghrib) only on Ramadan days (`isRamadanDay`). Hijri correction −2…+2 days. |
| Qibla | `Sukun/Features/Qibla/` | Compass dial (always LTR, also in Arabic), bearing, distance, guidance "Turn right 20°", aligned within ±3° → green wash, `.success` haptic (setting), VoiceOver announcement. |
| Settings | `SettingsView` | Location (city search / GPS), method, Asr (madhab), high latitudes, adjustments, notifications, early/Jumu'ah/Suhoor, Ramadan, Hijri correction, pattern toggle, Qibla haptics, feedback. Debug builds: "Design preview" (jump to a time of day). |
| Feedback | `FeedbackService`, `FeedbackView` | Native form → one HTTPS POST to a PostHog **API-type survey** (EU cloud, `eu.i.posthog.com/i/v0/e/`, event "survey sent"). No SDK, random id per message, no location. `appStoreID` 6832348832 enables "Rate Sukun". |
| Rating prompt | `ReviewPrompt`, `TodayView.askForReviewIfDue` | Apple's rating dialog only after 7 different days of app use and 14+ days since first use, on Today after 3 s while a prayer is running, once per version, not within 14 days of a "Problem"/"Wrong times" feedback. Widgets don't count. "Rate Sukun" link in Settings always available. |
| Widgets | `SukunWidgets/` | Current Prayer (small + Lock Screen circular/rectangular/inline; kind id still `faith.sukun.widget.next`, don't rename: users would lose placed widgets), Today's Prayers (medium), Overview (large), Qibla (small). Timeline: one entry per prayer boundary + midnight for 48 h; countdowns via `Text(.timer)`. Always-On (`isLuminanceReduced`) shows a short clock time instead of a ticking countdown. Tinted/clear modes: highlight becomes an outline (`CurrentHighlight`, `widgetRenderingMode`). No widget style options: iOS Clear/Tinted cover it. |
| Website | `website/` | Static HTML/CSS EN+DE (home, privacy incl. PostHog feedback, support, imprint: Jason Schell, Munich), deployed to Cloudflare Workers static assets (`wrangler.jsonc`, `website/_headers` with a strict CSP, `website/_redirects`; `npm run dev` / `npm run deploy`). No scripts, no cookies: keep it that way, the CSP blocks scripts. |

## 3. Architecture and code map

```
project.yml                 XcodeGen spec (source of truth; Sukun.xcodeproj is generated, don't edit it)
Packages/SukunKit/          Swift package shared by app and widget (Adhan 1.5 dependency)
  Calculation/              PrayerCalculator, PrayerSnapshot, CalculationConfiguration, RegionalDefaults,
                            NotificationPlan (pure), Ramadan, QiblaCalculator, Formatting (PrayerTimeFormatter,
                            widthSamples, CivilDate, HijriDate)
  Models/                   PrayerKind, SukunSettings (tolerant, clamped Codable), ReminderOptions,
                            Coordinate/StoredLocation, L10n, VoiceControlNames
  Persistence/SharedStore   App Group UserDefaults (settings, last GPS fix)
  Location/                 LocationResolver (fix → place), PlaceSearch (MapKit city search)
  Design/                   Palette, TimeOfDayGradient, Typography, GeometricPattern
  Resources/Localizable.xcstrings   strings used by kit + widgets
Sukun/                      App target
  SukunApp.swift            entry, RootView (TabView Today/Qibla/Settings), sukun:// deep links
  Services/AppModel         @Observable app state; persists to SharedStore; reloads widgets; design preview clock
  Services/                 LocationService, NotificationScheduler, NotificationText, BackgroundRefresh
                            (task faith.sukun.ios.refresh), FeedbackService, ScreenshotMode (DEBUG only)
  Features/                 Today, Qibla, Settings, Location
  Resources/                Localizable.xcstrings, InfoPlist.xcstrings, Assets
SukunWidgets/               Provider/PrayerTimelineProvider, Views/WidgetComponents (CurrentHighlight,
                            UpcomingHint, RamadanLine, QiblaArrowDial…), Widgets/*
SukunTests/                 App tests (AppModel, notifications text, feedback, adjustments, accessibility tree)
docs/                       APP_STORE_CHECKLIST, APP_STORE_METADATA (+ check_metadata.py), ACCESSIBILITY,
                            ICONS, screenshots/{en,de,ar}, superpowers/specs + plans (launch features design)
scripts/app-store-screenshots.sh   regenerates the App Store screenshots
```

Data flow: `SukunSettings` + `StoredLocation` → `CalculationConfiguration` → `PrayerCalculator` (Adhan) →
`PrayerSnapshot` (what to show now) / `NotificationPlan` (what to schedule) / widget timeline.
`AppModel.update { }` is the single write path for settings: it persists, reschedules notifications and
calls `WidgetCenter.reloadAllTimelines()`.

Key rules in the logic (all covered by tests; keep them green):
- Notification budget 60 (iOS cap 64), rolling window up to 7 days, at most **one extra** per prayer;
  Suhoor replaces Fajr's early reminder, Jumu'ah replaces Dhuhr's on Fridays. Past reminders are skipped,
  never sent late. The plan starts one day earlier so Isha after midnight isn't dropped.
- Regional defaults: method by country (Umm al-Qura SA, Diyanet TR, ISNA North America, Karachi South Asia,
  Dubai AE, Moonsighting Committee GB, MWL elsewhere…), Hanafi Asr in South Asia, seventh-of-the-night rule above 48°.
- `CivilDate` is always Gregorian (ar_SA would otherwise show Hijri twice). `HijriDate` applies the correction.
- Times use the location's time zone and the system 12/24 h setting (or the user's override).

## 4. Build, test, run

```bash
brew install xcodegen
xcodegen generate                                   # after every project.yml or file add/remove
xcodebuild test -project Sukun.xcodeproj -scheme Sukun \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'   # app tests + SukunKit tests
cd Packages/SukunKit && swift test                  # kit only, also on Linux
python3 docs/check_metadata.py                      # App Store text limits
```

- **Bar:** 0 warnings, all tests green. The code is clean under `SWIFT_STRICT_CONCURRENCY=complete`
  (project.yml sets `minimal`; check with the build setting override before committing).
- Write a failing test first for logic changes (the repo was built test-first).
- `PrayerRowAccessibilityTests` switch on automation accessibility (`_AXSSetAutomationEnabled`) to inspect
  the real UIKit accessibility tree SwiftUI builds; reuse that pattern for VoiceOver checks.
- Debug launch arguments (DEBUG builds only, see `ScreenshotMode.swift`, `RootView`):
  `-SukunInitialTab today|qibla|settings`, `-SukunScreenshotCity london|berlin|dubai`,
  `-SukunDesignPreview fajr|sunrise|dhuhr|asr|maghrib|isha`, `-SukunScreenshotDay 2027-02-20`, `-SukunPreviewMinutes 90` (minutes after the previewed prayer, `m5` = 5 before),
  `-SukunFakeQiblaOffset 0` (simulated compass), plus `-AppleLanguages "(ar)" -AppleLocale ar_AE`.
- Screenshots: `scripts/app-store-screenshots.sh` (header explains usage) → `docs/screenshots/`. Set the
  simulator UDID in the script. Status bar clock is synced to the time shown on screen.
- Simulator gotchas: no compass (use the fake offset); writing app prefs with `defaults` doesn't stick,
  reinstall for a clean state; `simctl openurl` can leave a stuck "Open in Sukun?" dialog, so use launch arguments.

## 5. Design system (decided with the owner, don't drift)

- Light mode: cream background with **time-of-day gradients** (Fajr pink-violet, sunrise gold, midday
  green-grey, Asr gold, Maghrib apricot, Isha blue-grey). The owner likes them; keep them.
- Dark mode: **neutral charcoal** (`111413`, surface `1B201E` @ 0.9), gradients dimmed. Green only for
  signals (bells on, Qibla aligned, current highlight `6FB892` @ 0.16). Current prayer text is white, not green.
- Accent: light `4E8A6A`, text-safe `2B6449`; dark accent `6FAE8C`, text `8CC3A5`. Secondary text light
  `525D62`, dark `A4AAA7`. All tokens live in `Palette.swift` / `TimeOfDayGradient.swift`: use them, no ad-hoc colors.
- Typography: SF Rounded. Hero/bearing numerals are **thin** (`.thin`); with Increase Contrast `.light`.
  Do not make them heavier by default. Row times `sukunTime` (light, monospaced digits) with a fixed-width
  column (`widthSamples`) so bells align vertically.
- Past prayers: **50 % opacity** (owner preference). Readable grey instead only with Increase Contrast.
- Current prayer: semibold + rounded highlight; next prayer only as a small hint.
- Subtle geometric pattern (toggle in Settings). Scroll bounce only when content overflows
  (`.scrollBounceBehavior(.basedOnSize)`); Qibla shouldn't scroll at normal sizes.
- Motion through `Animation.sukun(reduceMotion:)`; respect Reduce Motion everywhere.
- Haptics: Qibla alignment `.success` (deliberately strong), bell `.selection`.
- App icons: see `docs/ICONS.md` (light + dark variants).

## 6. Product decisions: what not to add (unless the owner asks)

- No Adhan/call-to-prayer sounds, no "hadith/verse of the day" (postponed).
- No Mawaqit or any online prayer-time source; stay offline.
- No analytics or crash SDKs, no PostHog SDK (feedback uses a plain POST).
- No widget style/theme picker.
- No encryption documentation needed (`ITSAppUsesNonExemptEncryption` = NO, standard HTTPS only).
- No push notifications/APNs; local notifications are enough.
- App Store name "Sukun: Prayer Times & Qibla" (not just "Sukun").
- No ads, no subscription, no in-app purchases (one-time price). Marketing tells the owner's story as a revert
  (say "revert", never "new Muslim" or "convert").
- Name Jason Schell everywhere (imprint, privacy, copyright "2026 Jason Schell", store texts). Imprint and privacy
  policy add "exciting IT - Swetlana Schell" under the name (owner's wording); the imprint also has the VAT ID
  DE363509747. Nowhere else.

## 7. Localization

- String Catalogs: `Sukun/Resources/Localizable.xcstrings`, `InfoPlist.xcstrings`, widget and kit catalogs.
  English source; **every key needs `de` and `ar`** (`LocalizationCoverageTests` fails otherwise).
- Arabic entries are marked `needs_review`; a native reviewer sends corrections over time; update them per
  release. Arabic layout is RTL except the compass dial and Qibla arrow (forced LTR on purpose).
- Use `LocalizedStringKey`/`String(localized:)`; `Text(verbatim:)` only for non-translatable text.
- App Store texts for all three languages: `docs/APP_STORE_METADATA.md` (Arabic so far: name + subtitle).

## 8. Accessibility (claimed "Yes" for all applicable features in App Store Connect)

- Dynamic Type to AX5 (rows switch to a vertical layout), Dark Mode, Reduce Motion,
  Differentiate Without Color, Increase Contrast (heavier numerals, grey past prayers).
- VoiceOver: each prayer row is **one element**: label "Isha, 18:14[, current prayer]", value
  "Notification on/off", reads as a switch (double tap toggles), plus a custom action in the Actions
  rotor. The bell must **not** become a separate element (owner decision). Sunrise has no bell, no action.
  No `.isSelected` trait on the current prayer. Qibla readout = one element with live guidance as value
  (`.updatesFrequently`) and an announcement when aligned.
- Voice Control: `accessibilityInputLabels` with visible name, plain description and common dictation
  spellings (`VoiceControlNames`, e.g. "Night prayer", "Aisha", "Zuhr", "Maghreb", "Compass", "Kibla").
- Device test scripts and App Store answers: `docs/ACCESSIBILITY.md`. Re-run them when UI changes.

## 9. Release status and open items

- Release steps: `docs/APP_STORE_CHECKLIST.md`. Metadata: `docs/APP_STORE_METADATA.md`. Screenshots: `docs/screenshots/`.
- Open: `support@sukun.faith` mailbox;
  PostHog DPA + "Discard client IP data"; Arabic description/keywords/
  promotional text and Arabic website; marketing screenshots with captions (idea, not started).

## 10. Working agreements

- The owner writes in German; reply in the language they use. Keep explanations short and concrete.
- Ask before changing anything in Sections 5–6. Prefer small commits with a clear message.
- Regenerate the project (`xcodegen generate`) instead of editing `Sukun.xcodeproj`. Xcode Cloud does the same in
  `ci_scripts/ci_post_clone.sh` (installs XcodeGen, generates, copies SukunKit's `Package.resolved` into the project).
  Keep that script working when you add dependencies.
- Generated files (Info.plists, entitlements) and `.superpowers/` are git-ignored.
- Branch: `main` (default). Tag App Store releases `vX.Y.Z` on the commit of the submitted build.
- Never commit secrets. The PostHog project key in `FeedbackService.swift` is a public ingestion key by design.
