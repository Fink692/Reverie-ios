#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

select_simulator() {
    python3 - <<'PY'
import json
import re
import subprocess

data = json.loads(subprocess.check_output([
    'xcrun', 'simctl', 'list', 'devices', 'available', '--json'
]))
candidates = []
for runtime, devices in data['devices'].items():
    match = re.search(r'SimRuntime\.iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$', runtime)
    if not match:
        continue
    version = tuple(int(part or 0) for part in match.groups())
    if version < (17, 0, 0):
        continue
    for device in devices:
        if device['name'].startswith('iPhone') and device.get('isAvailable'):
            model = re.search(r'iPhone (\d+)', device['name'])
            generation = int(model.group(1)) if model else 0
            candidates.append((version, generation, 'Pro' in device['name'], device['name'], device['udid']))
if not candidates:
    raise SystemExit('No available iPhone simulator with iOS 17 or later. Install an iOS runtime in Xcode Settings > Components.')
print(max(candidates)[-1])
PY
}

case "${1:-all}" in
    --select-simulator) select_simulator; exit 0 ;;
    all|device|test) mode="${1:-all}" ;;
    *) echo 'Usage: verify-macos.sh [all|device|test|--select-simulator]' >&2; exit 2 ;;
esac

command -v xcodebuild >/dev/null || { echo 'Xcode and its command line tools are required.' >&2; exit 1; }
xcodebuild -version
if command -v xcodegen >/dev/null; then
    xcodegen generate
elif [[ -f Reverie.xcodeproj/project.pbxproj ]]; then
    echo 'Using the included Xcode project.'
else
    echo 'Xcode project missing. Install XcodeGen: brew install xcodegen' >&2
    exit 1
fi

if [[ "$mode" == all || "$mode" == device ]]; then
    xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath build-device \
        CODE_SIGNING_ALLOWED=NO build
fi

if [[ "$mode" == all || "$mode" == test ]]; then
    destination="${IOS_TEST_DESTINATION:-}"
    if [[ -z "$destination" ]]; then
        simulator_id="$(select_simulator)"
        destination="platform=iOS Simulator,id=$simulator_id"
    fi
    printf 'Testing on %s\n' "$destination"
    run_tests() {
        xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Debug \
            -destination "$destination" -destination-timeout 180 -derivedDataPath build \
            "$@" CODE_SIGNING_ALLOWED=NO test
    }
    if [[ -n "${IOS_TEST_RESULT_BUNDLE:-}" ]]; then
        run_tests -resultBundlePath "$IOS_TEST_RESULT_BUNDLE"
    else
        run_tests
    fi
fi
