#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -n "${SIMULATOR_ID:-}" ]] || { echo 'SIMULATOR_ID is required for brand startup screenshots.' >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo 'Xcode and its command line tools are required.' >&2; exit 1; }
[[ -f scripts/brand_bundle.py ]] || { echo 'Missing scripts/brand_bundle.py.' >&2; exit 1; }

startup_work="$(mktemp -d "${TMPDIR:-/tmp}/reverie-brand-startup.XXXXXX")"
trap 'rm -rf "$startup_work"' EXIT
mkdir -p brand-artifacts

python3 - "$startup_work" <<'PY'
from pathlib import Path
import json
import sys

work = Path(sys.argv[1])
raw = json.loads(Path('References/Branding/variants.json').read_text())
variants = raw['variants'] if isinstance(raw, dict) else raw
representatives = {
    'commerce': 'commerce',
    'chase': 'banking',
    'robinhood': 'portfolio',
    'phantom': 'wallet',
    'polymarket': 'prediction',
}
selected = []
for name, kind in representatives.items():
    matches = [entry for entry in variants if entry['id'] == name]
    if len(matches) != 1 or matches[0].get('playbackKind') != kind:
        raise SystemExit(f'Missing or invalid {kind} startup representative: {name}.')
    selected.append(matches[0])
with (work / 'variants.tsv').open('w') as rows:
    for entry in selected:
        rows.write('\t'.join(entry[key] for key in ('id', 'displayName', 'bundleIdentifier')) + '\n')
PY

# Compile all icon resources once. CI's native tests use the same settings, so
# this build reuses their Debug executable and catalog rather than each flavor
# compiling the Swift application again.
brand_icons="$(./scripts/verify-macos.sh --brand-icon-names)"
xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath build \
    ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS=YES \
    "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES=$brand_icons" \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | tee brand-artifacts/startup-base-simulator-build.log

startup_base=build/Build/Products/Debug-iphonesimulator/Reverie.app
startup_catalog=brand-artifacts/compiled-simulator-icons.json
python3 scripts/brand_bundle.py inspect-base --base-app "$startup_base" \
    --platform iPhoneSimulator --output-json "$startup_catalog"
xcrun simctl bootstatus "$SIMULATOR_ID" -b
while IFS=$'\t' read -r startup_id startup_name startup_bundle; do
    startup_app="$startup_work/$startup_id/Reverie.app"
    python3 scripts/brand_bundle.py prepare --base-app "$startup_base" \
        --output-app "$startup_app" --variant-id "$startup_id" --platform iPhoneSimulator \
        --catalog-evidence "$startup_catalog"
    xcrun simctl install "$SIMULATOR_ID" "$startup_app"
    startup_container="$(xcrun simctl get_app_container "$SIMULATOR_ID" "$startup_bundle" app)"
    python3 scripts/brand_bundle.py validate --app "$startup_container" \
        --variant-id "$startup_id" --platform iPhoneSimulator \
        --catalog-evidence "$startup_catalog" \
        --output-json "brand-artifacts/$startup_id-installed-info.json"
    # No UI-test brand override is supplied: startup reads the installed Info.plist.
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$startup_bundle" \
        -welcomed YES -AppleLanguages '(en)' -AppleLocale en_US
    sleep 5
    xcrun simctl io "$SIMULATOR_ID" screenshot "brand-artifacts/$startup_id-startup-simulator.png"
    xcrun simctl terminate "$SIMULATOR_ID" "$startup_bundle"
    sleep 2
    xcrun simctl io "$SIMULATOR_ID" screenshot "brand-artifacts/$startup_id-springboard-simulator.png"
done < "$startup_work/variants.tsv"

echo 'Captured production Info.plist startup screenshots for Shopify, Chase, Robinhood, Phantom, and Polymarket simulator variants.'
