#!/bin/sh
# Xcode Cloud: Sukun.xcodeproj is generated from project.yml (XcodeGen) and not committed.
# This runs right after the clone, before Xcode Cloud resolves packages and builds.
set -e
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

brew install xcodegen
xcodegen generate

# Xcode Cloud disables automatic package resolution and needs the project's Package.resolved.
# The only remote dependency (Adhan) comes through SukunKit, whose pins are committed.
mkdir -p Sukun.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp Packages/SukunKit/Package.resolved Sukun.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
