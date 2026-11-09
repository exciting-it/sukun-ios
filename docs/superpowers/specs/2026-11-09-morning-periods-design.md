# Morning periods: Sunrise, Duha, shortly before Dhuhr (design)

Status: agreed with the owner in chat on 2026-11-09. Ships in **v1.0**.

## Why

Between sunrise and Dhuhr no obligatory prayer is running (`PrayerSnapshot.current == nil`). Today the hero
then shows `featured = upcoming`, i.e. **"Dhuhr" with a large time**, only the name a bit greyer. It reads as
"Dhuhr is now". The Lock Screen and Home Screen widgets do the same. Every user sees this every morning.

Second, the owner (a revert since March 2026) didn't know that there are short times in which one does not
pray (while the sun rises, shortly before Dhuhr) or that Duha exists. Many users are like that; others know it
well. Sukun is for everyone and must stay calm and uncluttered.

## Goals

1. Never show Dhuhr in the hero (or any widget) as if it were running before it starts. **For everyone,
   regardless of the setting.**
2. With the new setting on (default), name the morning period in plain words and say, as a fact with a time,
   when one does not pray: "No prayer until 07:32".
3. Same logic in app, all widgets, Lock Screen (incl. Always-On), and VoiceOver.

## Non-goals and anti-goals

- No religious rulings or advice (no "missed Fajr? …", no "excellent time for nafl"). Times and plain labels only.
- No warning colors, badges, banners, pop-ups, or extra explanation screens. No amber. Palette unchanged.
- No onboarding question. No configurable minute values.
- The prayer list stays at **6 rows** (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha). No Duha row.
- No window before Maghrib (Asr is still valid then; showing it would confuse).
- No notifications for these periods.
- Notification logic (`NotificationPlan`) is unchanged.

## Behaviour

Let `S` = sunrise, `D` = Dhuhr (both as calculated today, incl. user adjustments).
Constants (owner-approved defaults, one place in SukunKit, easy to change later):
`sunriseWindow = 15 min`, `beforeDhuhrWindow = 10 min`.

| Time | Setting ON (default) | Setting OFF |
|---|---|---|
| `S ≤ t < S+15` | Title **Sunrise**, big time = S, line **"No prayer until {S+15}"** | Title **Morning**, big time = S, line **"Dhuhr in {countdown}"** |
| `S+15 ≤ t < D−10` | Title **Duha**, big time = S+15, line **"Dhuhr in {countdown}"** | Title **Morning**, as above |
| `D−10 ≤ t < D` | Title **Shortly before Dhuhr**, big time = D−10, line **"No prayer until {D}"** | Title **Morning**, as above |
| any other time | unchanged (current prayer + "Next … in …") | unchanged |

Notes:
- Big time for "Morning" (setting off) = sunrise time, consistent with "the period started at …" like
  "Isha since 18:15". (Builder may show it the same way as the other morning states.)
- **The line under the numerals is one line everywhere** (hero and widgets). For Duha/Morning it is the
  existing hint wording with the prayer named: "Dhuhr in 3:12:04" (ticking). With Always-On
  (`isLuminanceReduced`) it becomes the static "Dhuhr at 11:51". "No prayer until 07:32" is static anyway and
  shows unchanged on Always-On. *(Builder-check answer, our call.)*
- **Short morning** (`S+15 ≥ D−10`, extreme latitudes or heavy adjustments): no Duha and no separate
  before-Dhuhr state; one Sunrise state from S to D with "No prayer until {D}". If even `S ≥ D` (impossible
  in practice), no morning state at all. *(Our call.)*
- **Ramadan in widgets** (one line slot): during the two no-prayer windows the morning line wins (it is short,
  time-critical, and Iftar is hours away); during Duha/Morning the Ramadan line (Iftar countdown) wins, as
  today. The hero keeps showing both lines. *(Our call.)*
- Ramadan: the Ramadan line (Iftar countdown) stays as today, under the hero.
- Design preview (debug) and screenshot mode keep working; add `-SukunDesignPreview` support for the new
  states if cheap (e.g. preview `sunrise` already lands at S+10 = Sunrise window).

### Hero styling
Same components as today. Title in `Palette.text` for Sunrise / Duha / Shortly before Dhuhr / Morning
(they are the *current* state now, not a greyed "upcoming" prayer). Numerals thin as everywhere. The line
under the numerals uses the existing hint style (`secondaryText`). No highlight row in the list during the
morning (the highlight stays reserved for a running obligatory prayer); past rows fade as today.

### Widgets
- **Current Prayer (small), Overview (large header), Today's Prayers (medium if it features a name):** same
  title/time/line as the hero.
- **Lock Screen rectangular:** title + time + line. **Inline:** e.g. "Duha · Dhuhr 11:51",
  "Sunrise · No prayer until 07:32", "Morning · Dhuhr 11:51". **Circular:** symbol + short time (builder's call
  on the symbol; keep it readable).
- **Always-On (`isLuminanceReduced`):** same short form rules as today (no ticking seconds).
- **Timeline:** add entries at `S+15` and `D−10` so widgets switch exactly then (today: one entry per
  boundary + midnight). The ON/OFF setting comes from `SharedStore`, so widgets follow it; changing the
  setting reloads timelines like every settings change.

### VoiceOver
Hero label examples: "Duha since 07:32. Next: Dhuhr at 11:51.", "Sunrise since 07:17. No prayer until 07:32.",
"Shortly before Dhuhr. No prayer until 11:51." Widgets' combined labels follow the same wording.

### Setting
- Model: new `SukunSettings` field (e.g. `showsMorningPeriods: Bool`, **default true**), tolerant decoding
  (missing key → true), round-trip tested like the other fields.
- UI: **first section at the very top of Settings**, above Location: a toggle
  **"Duha and no-prayer times"** with footer
  *"Shows the Duha time in the morning and the short times at sunrise and before Dhuhr when one doesn't pray."*

## Copy (all three languages; Arabic written by us, marked `needs_review` like all Arabic strings)

| Key meaning | English | German | Arabic |
|---|---|---|---|
| Sunrise period title | Sunrise | Sonnenaufgang | الشروق |
| Duha title | Duha | Duha | الضحى |
| Before Dhuhr title | Shortly before Dhuhr | Kurz vor Dhuhr | قُبيل الظهر |
| Setting-off title | Morning | Vormittag | الصباح |
| No-prayer line | No prayer until %@ | Kein Gebet bis %@ | لا صلاة حتى %@ |
| Next line (Always-On) | Dhuhr at %@ | Dhuhr um %@ | الظهر الساعة %@ |
| Setting toggle | Duha and no-prayer times | Duha und Gebetspausen | الضحى وأوقات النهي عن الصلاة |
| Setting footer | Shows the Duha time in the morning and the short times at sunrise and before Dhuhr when one doesn't pray. | Zeigt am Vormittag die Duha-Zeit und die kurzen Zeiten bei Sonnenaufgang und vor Dhuhr, in denen man nicht betet. | يعرض وقت الضحى صباحًا والأوقات القصيرة عند الشروق وقبيل الظهر التي لا يُصلّى فيها. |

Prefer formats that reuse existing prayer-name localization for "Dhuhr" rather than hard-coding it.
`LocalizationCoverageTests` must stay green (every key in de + ar).

## Where it lives (builder may refine)

- **SukunKit:** a pure `MorningPeriod` (or `HeroState`) computed in/next to `PrayerSnapshot` from `today`,
  `date` and the setting: `.sunrise(until:)`, `.duha(since:)`, `.beforeDhuhr(since:)`, `.morning(since:)`,
  or nil outside the morning. All UIs render from it so they can't disagree. Widget timeline dates come from
  the same place.
- **App:** `FeaturedPrayerHero` in `TodayView.swift`; Settings top section; accessibility label.
- **Widgets:** `NextPrayerWidget`, `OverviewWidget`, `DayPrayersWidget` (if affected), `WidgetComponents`
  (`UpcomingHint`), `PrayerTimelineProvider`.
- **Docs:** `AGENTS.md` features table and design rules; `docs/ACCESSIBILITY.md` VoiceOver step if wording changes.

## Tests (write first)

- Period boundaries: at S, S+14:59, S+15, D−10:01, D−10, D−0:01, D → expected state, ON and OFF.
- OFF never yields Sunrise/Duha/Before-Dhuhr; ON/OFF never feature Dhuhr as running before D.
- Edge case: short morning (S+15 ≥ D−10) → no Duha, no overlap.
- Timeline includes S+15 and D−10 entries.
- Settings: default true, decoding old JSON → true, round-trip.
- Localization coverage (existing test) passes.

## Left to the builder

Exact type and property names; circular Lock Screen symbol; whether the medium widget shows a title at all;
how `-SukunDesignPreview` reaches the new states; App Store screenshots only need regenerating if the
existing ones show the morning (they don't: Asr, Isha, Fajr, Maghrib, Settings).
