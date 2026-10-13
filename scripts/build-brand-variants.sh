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

command -v ditto >/dev/null || { echo 'The macOS ditto command is required.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 1; }
base_app=build-device/Build/Products/Release-iphoneos/Reverie.app
[[ -d "$base_app" ]] || { echo 'Compiled base device app missing. Run ./scripts/verify-macos.sh device first.' >&2; exit 1; }

variant_work="$(mktemp -d "${TMPDIR:-/tmp}/reverie-variants.XXXXXX")"
trap 'rm -rf "$variant_work"' EXIT
mkdir -p brand-artifacts

python3 scripts/brand_bundle.py list --only "$only_variant" --format tsv > "$variant_work/variants.tsv"
python3 scripts/brand_bundle.py inspect-base --base-app "$base_app" --platform iPhoneOS \
    --only "$only_variant" --output-json brand-artifacts/compiled-device-icons.json

while IFS=$'\t' read -r variant_id variant_display_name variant_bundle_id variant_icon variant_kind; do
    variant_payload="$variant_work/$variant_id/Payload"
    python3 scripts/brand_bundle.py prepare --base-app "$base_app" \
        --output-app "$variant_payload/Reverie.app" --variant-id "$variant_id" --platform iPhoneOS \
        --output-json "brand-artifacts/$variant_id-packaged-info.json"
    variant_ipa="brand-artifacts/Reverie-$variant_id-unsigned.ipa"
    rm -f "$variant_ipa"
    ditto -c -k --keepParent "$variant_payload" "$variant_ipa"
done < "$variant_work/variants.tsv"

python3 scripts/brand_bundle.py validate-packages --directory brand-artifacts --base-app "$base_app" \
    --platform iPhoneOS --only "$only_variant" --output-json brand-artifacts/manifest.json
