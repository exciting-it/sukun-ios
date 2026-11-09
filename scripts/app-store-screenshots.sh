#!/bin/zsh
# App Store screenshots (6.9", 1320x2868) for en, de, ar. Run from the repo root after a Debug build:
#   xcodebuild build -scheme Sukun -destination "platform=iOS Simulator,name=iPhone 18 Pro Max" -derivedDataPath build/dd
#   scripts/app-store-screenshots.sh build/dd/Build/Products/Debug-iphonesimulator/Sukun.app docs/screenshots
# Set DEV to your iPhone Pro Max simulator UDID (xcrun simctl list devices).
set -e
DEV=5099B4BB-8A94-4FA2-9708-4E467E9B6DE1
APP="$1"; OUT="$2"; shift 2
xcrun simctl boot $DEV 2>/dev/null || true
xcrun simctl bootstatus $DEV -b >/dev/null
xcrun simctl status_bar $DEV override --time "9:41" --dataNetwork wifi --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl uninstall $DEV faith.sukun.ios 2>/dev/null || true
xcrun simctl install $DEV "$APP"
shot() { # locale lang city name appearance tab preview day qibla
  local loc=$1 lang=$2 city=$3 name=$4 look=$5 tab=$6 prev=$7 day=$8 q=$9
  xcrun simctl ui $DEV appearance $look
  xcrun simctl terminate $DEV faith.sukun.ios 2>/dev/null || true
  local extra=()
  [[ $q != - ]] && extra+=(-SukunFakeQiblaOffset $q)
  [[ $day != - ]] && extra+=(-SukunScreenshotDay $day)
  xcrun simctl launch $DEV faith.sukun.ios -AppleLanguages "($lang)" -AppleLocale $loc \
    -SukunScreenshotCity $city -SukunInitialTab $tab -SukunDesignPreview $prev "${extra[@]}" >/dev/null
  sleep 3
  local data=$(xcrun simctl get_app_container $DEV faith.sukun.ios data)
  local t=($(cat "$data/tmp/screenshot-time"))
  local fmt="%H:%M"; [[ $lang == ar ]] && fmt="%l:%M"
  xcrun simctl status_bar $DEV override --time "$(TZ=${t[2]} date -r ${t[1]} +$fmt | tr -d " ")"
  sleep 1.5
  mkdir -p "$OUT/$lang"
  xcrun simctl io $DEV screenshot "$OUT/$lang/$name.png" >/dev/null 2>&1
}
for spec in "en_GB en london" "de_DE de berlin" "ar_AE ar dubai"; do
  set -- ${=spec}
  shot $1 $2 $3 1-today light today asr - -
  shot $1 $2 $3 2-night dark today isha - -
  shot $1 $2 $3 3-qibla light qibla fajr - 0
  shot $1 $2 $3 4-ramadan light today maghrib 2027-02-20 -
  shot $1 $2 $3 5-settings light settings asr - -
done
xcrun simctl ui $DEV appearance light
