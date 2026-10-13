#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
xcodegen generate
xcodebuild -project Reverie.xcodeproj -scheme Reverie -destination "${IOS_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 16}" -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
