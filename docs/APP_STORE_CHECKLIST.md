# App Store submission checklist

## 1. Identity & signing
- [ ] `SUKUN_BUNDLE_ID`, `SUKUN_APP_GROUP`, `DEVELOPMENT_TEAM` set in `project.yml`, `xcodegen generate` re-run
- [ ] App Group exists and is enabled for **both** App IDs (app + `.widgets`). Automatic signing does this.
- [ ] App record created in App Store Connect with the same bundle ID; SKU set; primary language English; German added
- [ ] Version `1.0.0` / build `1` (bump `CURRENT_PROJECT_VERSION` for every upload)

## 2. Build quality
- [ ] `swift test` in `Packages/SukunKit` and ⌘U in Xcode pass
- [ ] Real device: deny location → city search works; allow location → widget updates after moving
- [ ] Real device: compass aligns and gives a haptic within ±3°; calibration hint appears near magnets
- [ ] Widgets in every family; light, dark, **tinted** (iOS 18 Home Screen → Edit → Customize) and StandBy
- [ ] Lock Screen circular / rectangular / inline
- [ ] Notifications fire at prayer time with the app closed; toggling off removes them
- [ ] Largest Dynamic Type (AX5) on Today, Qibla, Settings; VoiceOver pass on all three tabs
- [ ] Reduce Motion on: no rotating spring animations; gradient changes without animation
- [ ] German device language: all strings translated, 24h format, dates in German
- [ ] Archive with the Release config, no warnings about missing `containerBackground` or privacy manifest

## 3. App Store Connect metadata (en + de)
- [ ] Name: **Sukun** (30 chars max). Subtitle e.g. "Prayer Times & Qibla" / "Gebetszeiten & Qibla"
- [ ] Category: Lifestyle (secondary: Reference or Utilities)
- [ ] Description, keywords (prayer, salah, namaz, adhan, qibla, widget, gebetszeiten, …), promotional text
- [ ] Support URL (required) and Privacy Policy URL (required even when no data is collected; a simple page that says so is enough)
- [ ] Age rating questionnaire → 4+
- [ ] Price: free; availability: all regions
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

## 5. App Privacy ("nutrition label")
- [ ] **Data Not Collected.** Location is only processed on device and never sent off it, so it isn't "collected"
  in Apple's sense. City search goes to Apple's MapKit, which is Apple's own processing and isn't declared by the app.
- [ ] Tracking: **No**

## 6. Export compliance
- [ ] `ITSAppUsesNonExemptEncryption = NO` is set in Info.plist, so no question appears on upload

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
