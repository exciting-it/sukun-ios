#!/bin/zsh
# Home Screen and Lock Screen screenshots with real Sukun widgets, for en, de and ar.
# Usage (repo root): scripts/widget-screenshots.sh [simulator-udid] [out-dir]
# Only some languages: LANGS="ar ar_AE" scripts/widget-screenshots.sh
# Erases the simulator for each language, places the widgets through SpringBoard (UI test target
# SukunScreenshotUITests) and writes <out>/<lang>/6-home.png and 7-lock.png.
# Widgets show the real current time: the content (e.g. Isha at night) depends on when you run it.
set -e
DEV=${1:-5099B4BB-8A94-4FA2-9708-4E467E9B6DE1}
OUT=${2:-docs/screenshots}
TMP=$(mktemp -d)
for spec in ${(s:,:)${LANGS:-en en_GB,de de_DE,ar ar_AE}}; do
  set -- ${=spec}
  lang=$1; locale=$2
  xcrun simctl shutdown $DEV 2>/dev/null || true
  xcrun simctl erase $DEV
  xcrun simctl boot $DEV
  xcrun simctl bootstatus $DEV -b >/dev/null
  xcrun simctl spawn $DEV defaults write -g AppleLanguages -array $lang
  xcrun simctl spawn $DEV defaults write -g AppleLocale -string $locale
  xcrun simctl shutdown $DEV; xcrun simctl boot $DEV; xcrun simctl bootstatus $DEV -b >/dev/null
  xcrun simctl status_bar $DEV override --operatorName "" --dataNetwork wifi --wifiBars 3 --cellularMode active \
    --cellularBars 4 --batteryState discharging --batteryLevel 100
  rm -f $TMP/home.png $TMP/lock.png  # never copy a previous language's shots
  # Same time zone as this Mac, so the clock and the widgets agree (Berlin; Arabic name for ar).
  city=berlin; [[ $lang == ar ]] && city=berlin-ar
  TEST_RUNNER_SUKUN_LANG=$lang TEST_RUNNER_SUKUN_SHOT_DIR=$TMP TEST_RUNNER_SUKUN_APP_ARGS="-SukunScreenshotCity $city -AppleLanguages ($lang)" \
    xcodebuild test -project Sukun.xcodeproj -scheme SukunScreenshots -destination "platform=iOS Simulator,id=$DEV" \
    -derivedDataPath build/screenshots-ui -only-testing:SukunScreenshotUITests/WidgetScreenshotTests/testHomeScreen \
    -only-testing:SukunScreenshotUITests/WidgetScreenshotTests/testLockScreen | grep -E "error:|TEST (SUCC|FAIL)"
  mkdir -p $OUT/$lang
  cp $TMP/home.png $OUT/$lang/6-home.png
  cp $TMP/lock.png $OUT/$lang/7-lock.png
done
echo "Done: $OUT/{en,de,ar}/6-home.png, 7-lock.png"
