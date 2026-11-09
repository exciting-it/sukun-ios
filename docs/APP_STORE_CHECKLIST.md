# App Store submission checklist

## 1. Identity & signing
- [x] `SUKUN_BUNDLE_ID`, `SUKUN_APP_GROUP`, `DEVELOPMENT_TEAM` set in `project.yml`, `xcodegen generate` re-run
- [ ] App Group exists and is enabled for **both** App IDs (app + `.widgets`). Automatic signing does this.
- [ ] App record created in App Store Connect with the same bundle ID; SKU set; primary language English; German added
- [x] Version `1.0.0` / build `1`. Bump `CURRENT_PROJECT_VERSION` for every upload; both Info.plists read
  `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`, so app and widget always match

## 2. Build quality
- [x] `swift test` in `Packages/SukunKit` and ⌘U in Xcode pass (27 package + 4 app tests; 0 warnings, also with
  `SWIFT_STRICT_CONCURRENCY=complete`)
- [ ] Real device: deny location → city search works; allow location → widget updates after moving
- [ ] Real device: compass aligns and gives a haptic within ±3°; calibration hint appears near magnets
- [ ] Widgets in every family; light, dark, **tinted** (iOS 18 Home Screen → Edit → Customize) and StandBy
  (rendered off-device in light/dark/accented: OK; still check on a real Home Screen and in StandBy)
- [ ] Lock Screen circular / rectangular / inline
- [ ] Notifications fire at prayer time with the app closed; toggling off removes them
- [ ] Swipe the app away, keep a widget placed, don't open the app for 8+ days: reminders still arrive at prayer times (the plan only covers 7 days, so this proves the widget rescheduled)
  - Faster check (TestFlight): Settings → Diagnostics → turn on "Notify me when the widget plans", swipe the app away, travel or wait until fewer than 3 days of reminders are left; a quiet "Sukun diagnostics" note appears in Notification Center. Afterwards the log under Diagnostics shows the widget runs.
- [ ] Travel (or change location to another city with GPS): within ~3 h the widget shows the new place and reminders carry the new place name and times, without opening the app
- [x] Largest Dynamic Type (AX5) on Today, Qibla, Settings (simulator: everything scrolls, nothing truncated)
- [ ] VoiceOver pass on all three tabs (real device)
- [x] Reduce Motion on: no rotating spring animations; gradient changes without animation (all motion goes
  through `Animation.sukun(reduceMotion:)` or `reduceMotion ? nil : …`)
- [x] German device language: all strings translated, 24h format, dates in German (all string catalogs complete)
- [x] Archive with the Release config, no warnings about missing `containerBackground` or privacy manifest
  (verified unsigned; do the signed archive in Xcode)

## 3. App Store Connect metadata (en + de)
Drafts for every field: [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md) (limits checked by `check_metadata.py`).
- [ ] Name: **Sukun** (30 chars max). Subtitle e.g. "Prayer Times & Qibla" / "Gebetszeiten & Qibla"
- [ ] Category: Lifestyle (secondary: Reference or Utilities)
- [ ] Description, keywords (prayer, salah, namaz, adhan, qibla, widget, gebetszeiten, …), promotional text
- [ ] Support URL https://sukun.faith/support/ and Privacy Policy URL https://sukun.faith/privacy/ (`website/`, see README), both required even when no data is collected; a simple page that says so is enough
- [ ] Age rating questionnaire → 4+
- [ ] Price: 1.99 € tier; availability: all regions
- [ ] Paid Applications Agreement, tax forms and bank account in App Store Connect → Business (required before a paid app can go live)
- [ ] Copyright line

## 4. Screenshots
Required: **6.9" iPhone** (1320 × 2868 or 1290 × 2796). App Store Connect scales these down for smaller devices.
Suggested set of 5–6, per language:
1. Today screen at a calm time (e.g. dawn gradient), next prayer highlighted
2. Home Screen with Small + Medium + Large widgets
3. Lock Screen with circular ring + rectangular widget
4. Qibla compass aligned ("You are facing the Qibla")
5. Dark mode Today + Qibla widget
6. Settings (methods) — "Works offline. No tracking."

Tip: use the simulator with a manual city (e.g. Munich) so the times are stable, and `xcrun simctl status_bar booted override --time 9:41`.
Debug builds accept `-SukunInitialTab today|qibla|settings`, e.g.
`xcrun simctl launch booted faith.sukun.ios -AppleLanguages "(de)" -AppleLocale de_DE -SukunInitialTab qibla`.
The Qibla shot should come from a real device (the simulator has no compass).

## 4b. Accessibility (App Store Connect → Accessibility)
- [x] Dark Interface, Larger Text, Differentiate Without Color Alone, Reduced Motion, Sufficient Contrast (see `ACCESSIBILITY.md`)
- [ ] VoiceOver and Voice Control: run the device passes in `ACCESSIBILITY.md`, then tick them
- [ ] Captions / Audio Descriptions: leave unticked (no audio or video)

## 5. App Privacy ("nutrition label")
- [ ] Location is only processed on device and never sent off it, so it isn't "collected" in Apple's sense.
  City search goes to Apple's MapKit, which is Apple's own processing and isn't declared by the app.
- [ ] **Feedback form** (Settings → Send feedback, sent to PostHog EU). Apple's optional-disclosure exception
  needs the user's name in the form, which Sukun doesn't have, so declare it:
  - *User Content → Other User Content*: App Functionality; **not linked** to the user; not used for tracking
  - *Diagnostics → Other Diagnostic Data* (app/iOS version, device model): App Functionality; not linked; no tracking
  - Result on the product page: "Data Not Linked to You". Keep the form free of an email field, or this changes.
- [ ] PostHog: DPA signed, "Discard client IP data" on, survey "In-App Feedback" launched
- [ ] Tracking: **No**

## 6. Export compliance
- [x] `ITSAppUsesNonExemptEncryption = NO` is set in Info.plist, so no question appears on upload

## 7. Review notes (paste into "Notes" for App Review)
> Sukun calculates Islamic prayer times and the Qibla direction entirely on device using the open-source Adhan library.
> There is no login, no server, and no data collection.
> Location is requested to calculate times for the user's position, in the app and in the widgets
> (NSWidgetWantsLocation). If location is denied, the user can choose a city manually (Settings → Choose a city).
> Notifications are local and optional (Settings → Notifications).
> To test widgets: add "Sukun" widgets from the Home Screen gallery; Lock Screen widgets are under "Customize Lock Screen".
> The compass needs a physical device; the simulator shows the static bearing.

## 8. Submit
- [ ] Product → Archive → Distribute App → App Store Connect → Upload
- [ ] Wait for processing, attach build, optionally test via TestFlight (internal testers need no review)
- [ ] Submit for review. Choose manual release if you want to time the launch.
