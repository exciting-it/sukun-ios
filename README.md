# Sukun

Calm, private prayer times and Qibla for iPhone — built around Home Screen and Lock Screen widgets.

- Fully offline calculation with [Adhan](https://github.com/batoulapps/adhan-swift)
- No backend, no accounts, no analytics, no tracking
- iOS 17+, SwiftUI, WidgetKit · English & German

## Getting started

```bash
brew install xcodegen
xcodegen generate        # creates Sukun.xcodeproj from project.yml
open Sukun.xcodeproj
```

Before the first run, set your identity in **one place**, the `settings.base` block of `project.yml`:

| Setting | Example | Notes |
|---|---|---|
| `SUKUN_BUNDLE_ID` | `com.jasonschell.sukun` | Reverse-DNS, globally unique, **cannot change after the first App Store upload** |
| `SUKUN_APP_GROUP` | `group.com.jasonschell.sukun` | Must start with `group.`; shared by app and widget |
| `DEVELOPMENT_TEAM` | `5A57FGF7LP` | Your Team ID (developer.apple.com → Membership) |

Re-run `xcodegen generate` after editing `project.yml`. With automatic signing, Xcode registers the
App IDs and the App Group for you.

## Layout

```
Packages/SukunKit/   Shared Swift package (app + widget)
  Calculation/       Adhan wrapper, Qibla math, regional defaults, widget timeline planning, formatting
  Models/            PrayerKind, settings, locations, localization helper
  Persistence/       SharedStore (App Group UserDefaults)
  Location/          One-shot location + reverse geocoding (also used by the widget), city search
  Design/            Palette, typography, time-of-day gradient, geometric pattern
  Tests/             Prayer time + Qibla tests (Munich, Mecca, …)
Sukun/               App target: Today, Qibla compass, Settings, notifications, background refresh
SukunWidgets/        Widget extension: small/medium/large/Qibla + Lock Screen accessories
SukunTests/          App-level tests
docs/                App Store checklist, icon guide
```

## How the widgets stay accurate

- **Timeline:** the provider emits one entry per prayer boundary (incl. sunrise) and per local midnight
  for the next 48 h. Countdowns use `Text(.timer)` / `ProgressView(timerInterval:)`, so they tick without
  extra entries. Widgets flip exactly at prayer times with ~1 reload every few hours.
- **Location:** the widget extension declares `NSWidgetWantsLocation`. When the user has allowed location
  for the app ("While Using the App or Widgets"), the widget takes its own fix (at most every 15 min,
  ~1 km accuracy) and reverse-geocodes only if the place changed. GPS users get a timeline reload every
  3 hours so travel is picked up; manual-location users reload only when the 48 h timeline runs out.
- **Fallbacks:** manual location override → fresh widget fix → last fix stored by the app.
- The app calls `WidgetCenter.reloadAllTimelines()` whenever settings or location change.

## Calculation defaults

"Automatic" picks a method from the location's country (Umm al-Qura in Saudi Arabia, Diyanet in Türkiye,
ISNA in North America, Karachi in South Asia, Muslim World League elsewhere, …), Hanafi Asr in South Asia,
and the *seventh of the night* high-latitude rule above 48° (Munich, Berlin, London…). Everything can be
overridden in Settings. See `RegionalDefaults.swift`.

## Tests

```bash
cd Packages/SukunKit && swift test     # runs on macOS and Linux
```

or ⌘U in Xcode (the `Sukun` scheme runs the package tests and the app tests).

Reference values come from an independent calculation (api.aladhan.com) for the same parameters;
tests allow ±2 minutes because Adhan applies small per-method safety offsets.

## Notifications

Local only. iOS caps pending notifications at 64, so Sukun keeps a rolling window of up to 7 days and
refreshes it when the app becomes active and via a background app refresh task (`app.sukun.refresh`).

## Privacy

`PrivacyInfo.xcprivacy` (app and widget) declares no tracking and no collected data. The only
required-reason API is `UserDefaults` (CA92.1, 1C8F.1 for the App Group). City search uses Apple's
MapKit; nothing is sent to any other service.
