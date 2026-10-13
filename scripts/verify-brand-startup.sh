#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -n "${SIMULATOR_ID:-}" ]] || { echo 'SIMULATOR_ID is required for brand startup screenshots.' >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo 'Xcode and its command line tools are required.' >&2; exit 1; }

startup_work="$(mktemp -d "${TMPDIR:-/tmp}/reverie-brand-startup.XXXXXX")"
trap 'rm -rf "$startup_work"' EXIT
mkdir -p brand-artifacts

python3 - "$startup_work" <<'PY'
from pathlib import Path
import json
import plistlib
import sys

work = Path(sys.argv[1])
source = Path('build/Build/Products/Debug-iphonesimulator/Reverie.app/Info.plist')
if not source.is_file():
    raise SystemExit('Base simulator app missing. Run the native simulator tests first.')
base = plistlib.loads(source.read_bytes())
if base.get('CFBundleIdentifier') != 'com.reverie.simulator':
    raise SystemExit('Simulator output must be the base Reverie app before startup checks.')
raw = json.loads(Path('References/Branding/variants.json').read_text())
variants = raw['variants'] if isinstance(raw, dict) else raw
selected = [next(entry for entry in variants if entry['id'] == name) for name in ('commerce', 'chase')]
for entry in selected:
    info = dict(base)
    for key in ('CFBundleIcons', 'CFBundleIcons~ipad', 'CFBundleIconFiles', 'CFBundleIconName', 'ReveriePlaybackKind', 'ReverieBankTheme'):
        info.pop(key, None)
    info['CFBundleIdentifier'] = entry['bundleIdentifier']
    info['CFBundleDisplayName'] = entry['displayName']
    info['ReveriePlaybackKind'] = entry['playbackKind']
    if entry.get('bankTheme'):
        info['ReverieBankTheme'] = entry['bankTheme']
    (work / f"{entry['id']}.plist").write_bytes(plistlib.dumps(info))
(work / 'variants.json').write_text(json.dumps(selected, indent=2) + '\n')
with (work / 'variants.tsv').open('w') as rows:
    for entry in selected:
        rows.write('\t'.join(entry[key] for key in ('id', 'displayName', 'bundleIdentifier', 'appIcon')) + '\n')
PY

xcrun simctl bootstatus "$SIMULATOR_ID" -b
while IFS=$'\t' read -r startup_id startup_name startup_bundle startup_icon; do
    xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath build \
        PRODUCT_NAME=Reverie PRODUCT_MODULE_NAME=Reverie \
        PRODUCT_BUNDLE_IDENTIFIER="$startup_bundle" \
        ASSETCATALOG_COMPILER_APPICON_NAME="$startup_icon" \
        GENERATE_INFOPLIST_FILE=NO INFOPLIST_FILE="$startup_work/$startup_id.plist" \
        INFOPLIST_KEY_CFBundleDisplayName="$startup_name" \
        CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "brand-artifacts/$startup_id-simulator-build.log"
    xcrun simctl install "$SIMULATOR_ID" build/Build/Products/Debug-iphonesimulator/Reverie.app
    startup_container="$(xcrun simctl get_app_container "$SIMULATOR_ID" "$startup_bundle" app)"
    python3 - "$startup_work" "$startup_id" "$startup_container" <<'PY'
from pathlib import Path
import json
import plistlib
import sys

entry = next(item for item in json.loads((Path(sys.argv[1]) / 'variants.json').read_text()) if item['id'] == sys.argv[2])
app = Path(sys.argv[3])
info = plistlib.loads((app / 'Info.plist').read_bytes())
for key, expected in [('CFBundleIdentifier', entry['bundleIdentifier']), ('CFBundleDisplayName', entry['displayName']), ('ReveriePlaybackKind', entry['playbackKind'])]:
    if info.get(key) != expected:
        raise SystemExit(f"Installed {entry['id']} has unexpected {key}.")
if info.get('ReverieBankTheme') != entry.get('bankTheme'):
    raise SystemExit(f"Installed {entry['id']} has unexpected bank theme.")
if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']:
    raise SystemExit(f"Installed {entry['id']} is not a simulator build.")
if not (app / 'Order.caf').is_file():
    raise SystemExit(f"Installed {entry['id']} is missing its order notification sound.")
print(f"Verified installed {entry['displayName']} simulator app metadata and bundled sound.")
PY
    # Set the existing onboarding preference for these isolated simulator checks.
    # No UI-test brand override is supplied: startup reads the installed Info.plist.
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$startup_bundle" \
        -welcomed YES -AppleLanguages '(en)' -AppleLocale en_US
    sleep 5
    xcrun simctl io "$SIMULATOR_ID" screenshot "brand-artifacts/$startup_id-startup-simulator.png"
    xcrun simctl terminate "$SIMULATOR_ID" "$startup_bundle"
done < "$startup_work/variants.tsv"

echo 'Captured production Info.plist startup screenshots for the Shopify and Chase simulator variants.'
