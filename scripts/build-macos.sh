#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen first: brew install xcodegen'; exit 1; }
python3 scripts/create_asset_catalog.py
# Build-time icon normalization to Apple's required raster dimensions.
sips --resampleHeightWidth 1024 1024 Marketing/app-icon-master.png --out App/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
xcodegen generate
swift test
mkdir -p build
xcodebuild -project RideGuard.xcodeproj -scheme RideGuard -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData -resultBundlePath build/iPhone.xcresult CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/iphone-build.log
xcodebuild -project RideGuard.xcodeproj -scheme RideGuardWatch -destination 'generic/platform=watchOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build 2>&1 | tee build/watch-build.log
