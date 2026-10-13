#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

only_variant=""
case "${1:-}" in
    "") ;;
    --only)
        [[ $# -eq 2 && -n "$2" ]] || { echo 'Usage: build-brand-variants.sh [--only variant-id]' >&2; exit 2; }
        only_variant="$2"
        ;;
    *) echo 'Usage: build-brand-variants.sh [--only variant-id]' >&2; exit 2 ;;
esac

command -v xcodebuild >/dev/null || { echo 'Xcode and its command line tools are required.' >&2; exit 1; }
command -v ditto >/dev/null || { echo 'The macOS ditto command is required.' >&2; exit 1; }
[[ -f References/Branding/variants.json ]] || { echo 'Missing References/Branding/variants.json.' >&2; exit 1; }
[[ -f Reverie.xcodeproj/project.pbxproj ]] || { echo 'Missing Reverie.xcodeproj. Generate the project first.' >&2; exit 1; }

variant_work="$(mktemp -d "${TMPDIR:-/tmp}/reverie-variants.XXXXXX")"
trap 'rm -rf "$variant_work"' EXIT
mkdir -p brand-artifacts

# Freeze the base application metadata before any variant build replaces it.
python3 - "$variant_work" "$only_variant" <<'PY'
from pathlib import Path
import json
import plistlib
import re
import shutil
import sys

work = Path(sys.argv[1])
requested = sys.argv[2]
base = Path('build-device/Build/Products/Release-iphoneos/Reverie.app/Info.plist')
if not base.is_file():
    raise SystemExit('Base device application missing. Run ./scripts/verify-macos.sh device first.')
base_info = plistlib.loads(base.read_bytes())
if base_info.get('CFBundleIdentifier') != 'com.reverie.simulator':
    raise SystemExit('Device output is not the base Reverie app. Rebuild with ./scripts/verify-macos.sh device first.')
shutil.copyfile(base, work / 'BaseInfo.plist')

raw = json.loads(Path('References/Branding/variants.json').read_text())
variants = raw['variants'] if isinstance(raw, dict) else raw
if not isinstance(variants, list) or not variants:
    raise SystemExit('variants.json must contain a nonempty variants array.')
ids = set()
bundles = set()
icons = set()
for entry in variants:
    for field in ('id', 'displayName', 'bundleIdentifier', 'appIcon', 'playbackKind'):
        value = entry.get(field)
        if not isinstance(value, str) or not value or any(char in value for char in '\t\r\n'):
            raise SystemExit(f'Invalid or missing variant field: {field}.')
    variant_id = entry['id']
    if not re.fullmatch(r'[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*', variant_id):
        raise SystemExit(f'Invalid variant ID: {variant_id}.')
    bundle = entry['bundleIdentifier']
    if not re.fullmatch(r'com\.reverie\.brand\.[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*', bundle):
        raise SystemExit(f'Invalid variant bundle identifier: {bundle}.')
    icon = entry['appIcon']
    if not re.fullmatch(r'Brand-[A-Za-z0-9-]+', icon):
        raise SystemExit(f'Invalid variant app icon name: {icon}.')
    if variant_id in ids or bundle in bundles or icon in icons:
        raise SystemExit('Variant IDs, bundle identifiers, and icon names must be unique.')
    ids.add(variant_id)
    bundles.add(bundle)
    icons.add(icon)
    if entry['playbackKind'] not in ('commerce', 'banking'):
        raise SystemExit(f'Invalid playback kind for {variant_id}.')
    theme = entry.get('bankTheme', '')
    if not isinstance(theme, str) or any(char in theme for char in '\t\r\n'):
        raise SystemExit(f'Invalid bankTheme for {variant_id}.')
    if entry['playbackKind'] == 'banking' and not re.fullmatch(r'[A-Za-z][A-Za-z0-9]*', theme):
        raise SystemExit(f'Banking variant {variant_id} requires a bankTheme.')
    if entry['playbackKind'] == 'commerce' and theme:
        raise SystemExit(f'Commerce variant {variant_id} must not have a bankTheme.')
    icon_set = Path('Sources/Assets.xcassets') / f'{icon}.appiconset'
    contents = icon_set / 'Contents.json'
    if not contents.is_file():
        raise SystemExit(f'Missing app icon set: {icon_set}.')
    images = json.loads(contents.read_text()).get('images', [])
    files = [image.get('filename') for image in images if image.get('filename')]
    if not files or any(not (icon_set / filename).is_file() for filename in files):
        raise SystemExit(f'Missing image data for app icon set: {icon_set}.')

selected = [entry for entry in variants if not requested or entry['id'] == requested]
if not selected:
    raise SystemExit(f'Unknown variant ID: {requested}.')
(work / 'variants.json').write_text(json.dumps(selected, indent=2) + '\n')
with (work / 'variants.tsv').open('w') as rows:
    for entry in selected:
        rows.write('\t'.join(entry[field] for field in ('id', 'displayName', 'bundleIdentifier', 'appIcon', 'playbackKind')) + '\n')
print(f'Preparing {len(selected)} unsigned brand variants from the base device application.')
PY

while IFS=$'\t' read -r variant_id variant_display_name variant_bundle_id variant_icon variant_kind; do
    variant_plist="$variant_work/$variant_id/Info.plist"
    python3 - "$variant_work" "$variant_id" <<'PY'
from pathlib import Path
import json
import plistlib
import sys

work = Path(sys.argv[1])
entry = next(item for item in json.loads((work / 'variants.json').read_text()) if item['id'] == sys.argv[2])
info = plistlib.loads((work / 'BaseInfo.plist').read_bytes())
for key in ('CFBundleIcons', 'CFBundleIcons~ipad', 'CFBundleIconFiles', 'CFBundleIconName', 'ReveriePlaybackKind', 'ReverieBankTheme'):
    info.pop(key, None)
info['CFBundleIdentifier'] = entry['bundleIdentifier']
info['CFBundleDisplayName'] = entry['displayName']
info['ReveriePlaybackKind'] = entry['playbackKind']
if entry.get('bankTheme'):
    info['ReverieBankTheme'] = entry['bankTheme']
destination = work / entry['id'] / 'Info.plist'
destination.parent.mkdir()
destination.write_bytes(plistlib.dumps(info))
PY

    printf 'Building %s (%s)\n' "$variant_display_name" "$variant_bundle_id"
    xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath build-device \
        PRODUCT_NAME=Reverie PRODUCT_MODULE_NAME=Reverie \
        PRODUCT_BUNDLE_IDENTIFIER="$variant_bundle_id" \
        ASSETCATALOG_COMPILER_APPICON_NAME="$variant_icon" \
        GENERATE_INFOPLIST_FILE=NO INFOPLIST_FILE="$variant_plist" \
        INFOPLIST_KEY_CFBundleDisplayName="$variant_display_name" \
        CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "brand-artifacts/$variant_id-build.log"

    variant_payload="$variant_work/$variant_id/Payload"
    mkdir -p "$variant_payload"
    ditto build-device/Build/Products/Release-iphoneos/Reverie.app "$variant_payload/Reverie.app"
    variant_ipa="brand-artifacts/Reverie-$variant_id-unsigned.ipa"
    rm -f "$variant_ipa"
    ditto -c -k --keepParent "$variant_payload" "$variant_ipa"
done < "$variant_work/variants.tsv"

# Inspect packaged bytes, rather than assuming build-setting overrides took effect.
python3 - "$variant_work" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import plistlib
import sys
import zipfile

work = Path(sys.argv[1])
records = []
for entry in json.loads((work / 'variants.json').read_text()):
    archive = Path('brand-artifacts') / f"Reverie-{entry['id']}-unsigned.ipa"
    with zipfile.ZipFile(archive) as payload:
        prefix = 'Payload/Reverie.app/'
        info = plistlib.loads(payload.read(prefix + 'Info.plist'))
        required = {
            'CFBundleIdentifier': entry['bundleIdentifier'],
            'CFBundleDisplayName': entry['displayName'],
            'ReveriePlaybackKind': entry['playbackKind'],
        }
        if entry.get('bankTheme'):
            required['ReverieBankTheme'] = entry['bankTheme']
        for key, value in required.items():
            if info.get(key) != value:
                raise SystemExit(f"{entry['id']}: packaged {key} is {info.get(key)!r}; expected {value!r}.")
        primary = info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {})
        if primary.get('CFBundleIconName') != entry['appIcon']:
            raise SystemExit(f"{entry['id']}: packaged app icon does not match {entry['appIcon']}.")
        if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
            raise SystemExit(f"{entry['id']}: package is not a physical-device iPhoneOS app.")
        if prefix + info.get('CFBundleExecutable', '') not in payload.namelist():
            raise SystemExit(f"{entry['id']}: app executable missing from IPA.")
        if prefix + 'Order.caf' not in payload.namelist():
            raise SystemExit(f"{entry['id']}: bundled order notification sound missing from IPA.")
        if prefix + 'embedded.mobileprovision' in payload.namelist():
            raise SystemExit(f"{entry['id']}: unexpected provisioning profile in unsigned package.")
        icons = primary.get('CFBundleIconFiles', [])
        if not icons or not all(any(name.startswith(prefix + icon) and name.endswith('.png') for name in payload.namelist()) for icon in icons):
            raise SystemExit(f"{entry['id']}: compiled primary app icon images missing from IPA.")
    records.append({**entry, 'file': archive.name, 'sizeBytes': archive.stat().st_size, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()})
manifest = {
    'generatedAt': datetime.now(timezone.utc).isoformat(),
    'platform': 'iPhoneOS',
    'signing': 'unsigned; Apple signing and provisioning required for installation',
    'variants': records,
}
Path('brand-artifacts/manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Verified {len(records)} packaged unsigned brand variants and wrote brand-artifacts/manifest.json.')
PY
