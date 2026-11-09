# Accessibility

## App Store Connect "Accessibility" answers (iPhone)

Re-evaluate with every update (Apple's rule). State as of version 1.0.0:

| Feature | Claim | Evidence |
|---|---|---|
| Dark Interface | Yes | Full dark mode in app and widgets |
| Larger Text | Yes | Dynamic Type up to AX5 (> 300 %) on Today, Qibla, Settings in en, de, ar: everything scrolls, no overlap, no clipping. Tab bar is exempt per Apple. |
| Differentiate Without Color Alone | Yes | Current prayer: bold + highlight shape; past prayers: faded; Qibla aligned: text + haptic; bell filled vs outline |
| Reduced Motion | Yes | All motion goes through `Animation.sukun(reduceMotion:)` / `reduceMotion ? nil : …` |
| Sufficient Contrast | Yes | Colors meet WCAG AA by default. Thin hero numerals and faded past prayers switch to heavier weight / readable grey with **Increase Contrast** (Apple's accepted route for system frameworks). Accessibility audit with Increase Contrast on: no contrast findings at default size; the remaining AX5 findings are elements behind the floating tab bar (readable once scrolled). |
| VoiceOver | Yes | Device pass done (version 1.0.0) |
| Voice Control | Yes | Device pass done (version 1.0.0) |
| Captions / Audio Descriptions | Not applicable | No audio or video |

Automated check: `XCUIApplication.performAccessibilityAudit()` on all tabs (light/dark, default size and AX5).

## Device pass: VoiceOver (about 15 minutes)

Settings → Accessibility → VoiceOver on (or triple-click the side button if set up). Do every step without looking.

1. **Onboarding** (delete and reinstall the app): both buttons ("Use my location", "Choose a city") are announced and work. City search: type a city, pick a result.
2. **Today:** swipe through. Expect: location ("Location: Munich", hint "Change location"), Hijri date, date, the hero ("Current prayer: Isha since 18:25. Next: Fajr at 05:24"), each row ("Fajr, 05:24"; the current one ends with "current prayer", without "Selected").
3. **Reminders:** a row with a bell reads as a switch ("Isha, 18:14, Notification off, switch button"). Double tap → the
   permission prompt appears; allow. Row value now says "Notification on". Also try the Actions rotor on a row: swipe
   up/down → "Turn notification off", double tap. Sunrise has no switch and no action.
4. **Qibla:** focus the readout: "Qibla direction 130 degrees, Southeast", then the guidance as its value ("Turn right 20°"). Keep it focused and turn: VoiceOver re-reads the guidance as it changes. When aligned, VoiceOver announces "You are facing the Qibla." wherever focus is, and the haptic fires.
5. **Settings:** change Method, Asr time, Adjust times (stepper: swipe up/down), Remind me before, Jumu'ah reminder (toggle, segmented choice, time picker), Ramadan mode, Hijri date stepper.
6. **Feedback:** open, choose a type, dictate text, Send, hear "Thank you".
7. **Widgets:** on the Home Screen, each widget reads as one sentence (e.g. "Current prayer: Asr since 14:19. Next: Maghrib at 16:43").

## Device pass: Voice Control (about 10 minutes)

Settings → Accessibility → Voice Control on.

1. "Tap Qibla", "Tap Settings", "Tap Today" switch tabs.
2. "Tap Munich" (or your city) opens the city picker; "Tap Cancel".
3. "Show names" on Today, then "Show actions for Isha" → "Turn notification on". Also try the plain names
   ("Show actions for Night prayer", "Dawn prayer", "Sunset prayer"; in German "Nachtgebet", "Morgengebet") and
   spellings dictation tends to produce ("Aisha", "Zuhr", "Maghreb"). "Show actions for Sunrise" offers no reminder.
   "Tap Compass" / "Tap Kibla" opens the Qibla tab.
4. Settings: "Tap Adjust times", "Tap Increment" on a stepper, "Go back"; "Tap Jumu'ah reminder", toggle it by name.
5. Feedback: "Tap Send feedback", "Type I like the widgets", "Tap Send".

If any step fails, note the screen and the spoken command and send it via Settings → Send feedback.
