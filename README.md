# Sukun

Calm, private prayer times and Qibla for iPhone — built around Home Screen and Lock Screen widgets.

- Fully offline calculation with [Adhan](https://github.com/batoulapps/adhan-swift)
- No backend, no accounts, no analytics, no tracking
- iOS 17+, SwiftUI, WidgetKit · English, German & Arabic

AI agents and new contributors: start with [AGENTS.md](AGENTS.md).

## Getting started

```bash
brew install xcodegen
xcodegen generate        # creates Sukun.xcodeproj from project.yml
open Sukun.xcodeproj
```

Before the first run, set your identity in **one place**, the `settings.base` block of `project.yml`:

| Setting | Example | Notes |
|---|---|---|
| `SUKUN_BUNDLE_ID` | `faith.sukun.ios` | Reverse-DNS, globally unique, **cannot change after the first App Store upload** |
| `SUKUN_APP_GROUP` | `group.faith.sukun` | Must start with `group.`; shared by app and widget |
| `DEVELOPMENT_TEAM` | `5A57FGF7LP` | Your Team ID (developer.apple.com → Membership) |

Re-run `xcodegen generate` after editing `project.yml`. With automatic signing, Xcode registers the
App IDs and the App Group for you.

## Xcode Cloud

`Sukun.xcodeproj` isn't committed. `ci_scripts/ci_post_clone.sh` installs XcodeGen, generates the project and
provides `Package.resolved` (Xcode Cloud doesn't resolve packages on its own). Workflow: scheme `Sukun`,
action Archive (iOS), distribution App Store Connect.

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
website/             sukun.faith (static, EN + DE): home, privacy, support, imprint
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

Local only. `NotificationPlan` (SukunKit) decides what fires when; `NotificationScheduler` (SukunKit) turns it into
requests. Three callers keep the plan alive:

- the app, whenever it becomes active or a setting changes;
- a background app refresh task (`faith.sukun.ios.refresh`), which iOS stops running once the app is swiped away;
- **the widget extension** on every timeline reload: iOS wakes widgets even when the app was swiped away for weeks.
  It plans again only when the place, time zone or settings differ from `SharedStore.notificationStamp`, or fewer
  than 3 days of reminders are left. So reminders keep coming and follow travel as long as a widget is placed.

Every plan ends with a quiet "Open Sukun to keep your prayer reminders coming." one hour after the last reminder.
Each new plan replaces it, so it only shows when nothing planned again (no widget, app never opened).

A nearby GPS fix reuses the stored place unless its name or country is missing (e.g. after landing without
internet), so the regional method and place name are looked up again once online. Rules:

- iOS caps pending notifications at 64; the plan keeps at most 60 over a rolling window of up to 7 days.
- Per prayer: the prayer notification plus at most one extra. Suhoor (Ramadan) replaces Fajr's early
  reminder; Jumu'ah (Friday) replaces Dhuhr's. Jumu'ah and Suhoor work without the prayer's own toggle.
- Reminders whose time has passed are skipped, not sent late. Days and weekdays are the location's.

## Adjustments and Ramadan

Per-time adjustments (−30…+30 min) live in `CalculationConfiguration`, so app, widgets and notifications
always agree. Ramadan mode (Automatic/On/Off) runs from Maghrib on the eve of 1 Ramadan to Maghrib on its last
day; the Hijri correction (−2…+2 days) shifts both the displayed date and this window.

## Privacy

`PrivacyInfo.xcprivacy` (app and widget) declares no tracking. The only required-reason API is
`UserDefaults` (CA92.1, 1C8F.1 for the App Group). City search uses Apple's MapKit. The only outbound
request of our own is the optional feedback form (Settings → Send feedback): one HTTPS POST to a PostHog
survey of type "API" in the EU cloud, no SDK, random id per message, no location. Config lives in
`Sukun/Services/FeedbackService.swift` (`FeedbackConfig.production`; `appStoreID` 6832348832 shows "Rate Sukun").

## Website

`website/` is plain HTML and CSS with no build step and no third-party requests (system fonts, inline SVG,
no scripts, no cookies). It is deployed to **Cloudflare Workers** as static assets (no Worker script):
`wrangler.jsonc` in the repo root, security and cache headers in `website/_headers`, short redirects in
`website/_redirects`, files that must not be uploaded in `website/.assetsignore`.

```bash
npm install          # installs Wrangler (pinned in package.json / package-lock.json)
npm run dev          # local preview on http://localhost:8787
npx wrangler login   # once
npm run deploy       # publishes to sukun.faith and www.sukun.faith
```

One-time setup: add `sukun.faith` to your Cloudflare account and switch the domain's nameservers to
Cloudflare. The first deploy then creates the custom domains (DNS records and certificates) from
`wrangler.jsonc`. For automatic deploys on push, connect the repository under Workers & Pages → the Worker →
Settings → Builds (deploy command `npx wrangler deploy`, root directory `/`).

Provider in imprint and privacy pages: Jason Schell, Munich. Make sure `support@sukun.faith` receives mail.
