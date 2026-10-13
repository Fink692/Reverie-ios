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
required_kinds = {'commerce', 'banking', 'portfolio', 'wallet', 'prediction'}
if {entry.get('playbackKind') for entry in variants} != required_kinds:
    raise SystemExit('Startup captures require all five reference scene styles.')
if len({entry['id'] for entry in variants}) != len(variants):
    raise SystemExit('Startup variant identities must be unique.')
with (work / 'variants.tsv').open('w') as rows:
    for entry in variants:
        rows.write('\t'.join(entry[key] for key in ('id', 'displayName', 'bundleIdentifier')) + '\n')
PY

# Capture-only verification can reuse the exact precompiled simulator bundle
# from a native build artifact. The normal workflow still builds once here.
if [[ -n "${STARTUP_BASE_APP:-}" ]]; then
    startup_base="$STARTUP_BASE_APP"
    [[ -d "$startup_base" && -f "$startup_base/Info.plist" ]] || {
        echo 'STARTUP_BASE_APP must point to a compiled iPhoneSimulator .app bundle.' >&2
        exit 1
    }
    echo "Reusing precompiled simulator application: $startup_base"
else
    # CI's native tests use the same settings, so this build reuses their Debug
    # executable and catalog instead of compiling each flavor again.
    brand_icons="$(./scripts/verify-macos.sh --brand-icon-names)"
    xcodebuild -project Reverie.xcodeproj -scheme Reverie -configuration Debug \
        -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath build \
        ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS=YES \
        "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES=$brand_icons" \
        CODE_SIGNING_ALLOWED=NO build 2>&1 | tee brand-artifacts/startup-base-simulator-build.log
    startup_base=build/Build/Products/Debug-iphonesimulator/Reverie.app
fi

# A successful simctl launch does not prove that the first app frame rendered.
# Inspect the middle of the screenshot, excluding status and home-indicator
# areas, so an all-white/black launch surface cannot count as startup evidence.
cat > "$startup_work/check-startup.swift" <<'SWIFT'
import Foundation
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count == 2,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Cannot decode startup screenshot.\n", stderr)
    exit(2)
}
let width = min(image.width, 320)
let height = max(1, image.height * width / image.width)
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
    guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    return true
}
guard rendered else {
    fputs("Cannot inspect startup screenshot pixels.\n", stderr)
    exit(2)
}
var colors: [UInt32: Int] = [:]
let top = height * 15 / 100
let bottom = height * 85 / 100
let bodyPixels = width * (bottom - top)
guard bodyPixels > 0 else { exit(2) }
for y in top..<bottom {
    for x in 0..<width {
        let offset = (y * width + x) * 4
        let color = (UInt32(pixels[offset] >> 3) << 10)
            | (UInt32(pixels[offset + 1] >> 3) << 5)
            | UInt32(pixels[offset + 2] >> 3)
        colors[color, default: 0] += 1
    }
}
let minimumCount = max(2, (bodyPixels + 999) / 1000)
let significantColors = colors.values.filter { $0 >= minimumCount }.count
let dominantFraction = Double(colors.values.max() ?? bodyPixels) / Double(bodyPixels)
print("Startup body: \(significantColors) significant color bins; dominant fraction \(String(format: "%.5f", dominantFraction)).")
guard significantColors >= 3, dominantFraction < 0.995 else {
    fputs("Startup body is blank or nearly one color.\n", stderr)
    exit(1)
}
SWIFT
xcrun swiftc "$startup_work/check-startup.swift" -o "$startup_work/check-startup"

startup_catalog=brand-artifacts/compiled-simulator-icons.json
python3 scripts/brand_bundle.py inspect-base --base-app "$startup_base" \
    --platform iPhoneSimulator --output-json "$startup_catalog"
xcrun simctl bootstatus "$SIMULATOR_ID" -b
startup_failed=0
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
    startup_capture="brand-artifacts/$startup_id-startup-simulator.png"
    startup_ready=0
    for startup_attempt in 1 2 3 4 5 6; do
        sleep 5
        xcrun simctl io "$SIMULATOR_ID" screenshot "$startup_capture"
        echo "$startup_name startup capture attempt $startup_attempt of 6"
        if "$startup_work/check-startup" "$startup_capture"; then
            startup_ready=1
            break
        fi
    done
    if [[ "$startup_ready" -ne 1 ]]; then
        echo "$startup_name did not render a nonblank startup body within 30 seconds." >&2
        startup_failed=1
        xcrun simctl spawn "$SIMULATOR_ID" log show --last 2m --style compact \
            --predicate "process == \"Reverie\" OR eventMessage CONTAINS \"$startup_bundle\"" \
            > "brand-artifacts/$startup_id-startup-diagnostics.log" 2>&1 || true
        for startup_crash in "$HOME"/Library/Logs/DiagnosticReports/Reverie*.ips "$HOME"/Library/Logs/DiagnosticReports/Reverie*.crash; do
            [[ -f "$startup_crash" ]] || continue
            cp "$startup_crash" "brand-artifacts/$startup_id-$(basename "$startup_crash")"
        done
    fi
    if ! xcrun simctl terminate "$SIMULATOR_ID" "$startup_bundle"; then
        echo "$startup_name was no longer running after startup capture." >&2
        startup_failed=1
    fi
    sleep 2
    xcrun simctl io "$SIMULATOR_ID" screenshot "brand-artifacts/$startup_id-springboard-simulator.png"
done < "$startup_work/variants.tsv"

if [[ "$startup_failed" -ne 0 ]]; then
    echo 'Startup evidence failed readiness verification; inspect captures and diagnostics.' >&2
    exit 1
fi
echo 'Captured production Info.plist startup and SpringBoard screenshots for every reference variant.'
