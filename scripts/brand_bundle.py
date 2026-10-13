#!/usr/bin/env python3
"""Clone one natively compiled app while preserving its executable and icon catalog."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent.parent
THEMES = {"bankTheme": "ReverieBankTheme", "portfolioTheme": "ReveriePortfolioTheme",
          "walletTheme": "ReverieWalletTheme", "predictionTheme": "ReveriePredictionTheme"}
KINDS = {"banking": "bankTheme", "portfolio": "portfolioTheme", "wallet": "walletTheme", "prediction": "predictionTheme"}
THEME_VALUES = {
    "bankTheme": {"chase", "bankOfAmerica", "wellsFargo", "citi", "capitalOne", "hsbc", "barclays", "lloyds", "natWest", "monzo", "revolut", "starling"},
    "portfolioTheme": {"robinhood", "wealthsimple", "coinbase"},
    "walletTheme": {"metamask", "phantom", "trustWallet"},
    "predictionTheme": {"polymarket"},
}
FAMILIES = ("CFBundleIcons", "CFBundleIcons~ipad")


class PackagingError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise PackagingError(message)


def load_variants(path):
    raw = json.loads(path.read_text())
    entries = raw.get("variants") if isinstance(raw, dict) else raw
    require(isinstance(entries, list) and entries, "variants.json must contain a nonempty variants array.")
    unique = {key: set() for key in ("id", "bundleIdentifier", "appIcon")}
    patterns = {"id": r"[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*", "appIcon": r"Brand-[A-Za-z0-9-]+",
                "bundleIdentifier": r"com\.reverie\.brand\.[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*"}
    for entry in entries:
        require(isinstance(entry, dict), "Each variant must be an object.")
        for field in ("id", "displayName", "bundleIdentifier", "appIcon", "playbackKind"):
            value = entry.get(field)
            require(isinstance(value, str) and value and not any(c in value for c in "\t\r\n"), f"Invalid variant field: {field}.")
        for field, pattern in patterns.items():
            require(re.fullmatch(pattern, entry[field]), f"Invalid variant {field}: {entry[field]}.")
            require(entry[field] not in unique[field], f"Duplicate variant {field}: {entry[field]}.")
            unique[field].add(entry[field])
        require(entry["playbackKind"] in ("commerce", *KINDS), f"Invalid playback kind: {entry['id']}.")
        required_theme = KINDS.get(entry["playbackKind"])
        for field in THEMES:
            if field == required_theme:
                value = entry.get(field)
                require(isinstance(value, str) and value in THEME_VALUES[field], f"{entry['id']} requires a supported {field} for {entry['playbackKind']}.")
            else:
                require(field not in entry, f"{entry['id']} must not contain {field}.")
        icon_set = ROOT / "Sources/Assets.xcassets" / (entry["appIcon"] + ".appiconset")
        require((icon_set / "Contents.json").is_file(), f"Missing icon set: {icon_set.name}.")
        names = [image.get("filename") for image in json.loads((icon_set / "Contents.json").read_text()).get("images", []) if image.get("filename")]
        require(names and all((icon_set / name).is_file() for name in names), f"Missing image data: {icon_set.name}.")
    return entries


def select(entries, variant_id):
    result = [entry for entry in entries if not variant_id or entry["id"] == variant_id]
    require(result, f"Unknown variant ID: {variant_id}.")
    return result


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_app(app):
    require((app / "Info.plist").is_file(), f"Compiled app Info.plist missing: {app}.")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    files = {path.relative_to(app).as_posix() for path in app.rglob("*") if path.is_file()}
    return info, files


def check_resources(info, files, platform, context):
    require(info.get("CFBundleSupportedPlatforms") == [platform], f"{context}: expected a {platform} application.")
    executable = info.get("CFBundleExecutable")
    require(isinstance(executable, str) and executable and Path(executable).name == executable and executable in files,
            f"{context}: executable missing.")
    for resource in ("Assets.car", "Order.caf", "PrivacyInfo.xcprivacy"):
        require(resource in files, f"{context}: {resource} missing.")
    require("embedded.mobileprovision" not in files and "_CodeSignature/CodeResources" not in files,
            f"{context}: signed base bundles cannot be repackaged as unsigned. Build with CODE_SIGNING_ALLOWED=NO.")
    return executable


def png_files(icon, files, context):
    names = icon.get("CFBundleIconFiles")
    require(isinstance(names, list) and names, f"{context}: compiled CFBundleIconFiles missing.")
    result = set()
    for name in names:
        require(isinstance(name, str) and name and Path(name).name == name, f"{context}: invalid icon filename.")
        stem = name[:-4] if name.endswith(".png") else name
        pattern = re.compile(re.escape(stem) + r"(?:@[23]x)?(?:~(?:ipad|iphone))?\.png")
        found = {filename for filename in files if pattern.fullmatch(filename)}
        require(found, f"{context}: compiled PNG missing for {name}.")
        result.update(found)
    return sorted(result)


def alternate_icon(info, files, entry, family):
    metadata = info.get(family, {}).get("CFBundleAlternateIcons", {}).get(entry["appIcon"])
    require(isinstance(metadata, dict),
            f"Base app lacks compiled {family} alternate icon {entry['appIcon']}. Rebuild once with all variant names in "
            "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES and ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS=YES.")
    require(metadata.get("CFBundleIconName", entry["appIcon"]) == entry["appIcon"], f"Unexpected catalog name: {entry['appIcon']}.")
    pngs = png_files(metadata, files, f"{entry['id']} {family}")
    return {"primaryIcon": {**metadata, "CFBundleIconName": entry["appIcon"]}, "pngFiles": pngs}


def inspect_base(app, entries, platform):
    info, files = read_app(app)
    require(info.get("CFBundleIdentifier") == "com.reverie.simulator", "Base bundle identifier must be com.reverie.simulator.")
    executable = check_resources(info, files, platform, "Base app")
    return {"platform": platform, "baseBundleIdentifier": info["CFBundleIdentifier"], "executable": executable,
            "executableSHA256": sha256((app / executable).read_bytes()), "assetCatalogSHA256": sha256((app / "Assets.car").read_bytes()),
            "compiledVariantCount": len(entries),
            "compiledIcons": {entry["id"]: {family: alternate_icon(info, files, entry, family) for family in FAMILIES} for entry in entries}}


def check_variant(info, files, entry, platform):
    executable = check_resources(info, files, platform, entry["id"])
    expected = {"CFBundleIdentifier": entry["bundleIdentifier"], "CFBundleDisplayName": entry["displayName"],
                "ReveriePlaybackKind": entry["playbackKind"]}
    for field, key in THEMES.items():
        if field in entry:
            expected[key] = entry[field]
        else:
            require(key not in info, f"{entry['id']}: unexpected {key}.")
    for key, value in expected.items():
        require(info.get(key) == value, f"{entry['id']}: {key} is {info.get(key)!r}; expected {value!r}.")
    icons = {}
    for family in FAMILIES:
        primary = info.get(family, {}).get("CFBundlePrimaryIcon", {})
        require(primary.get("CFBundleIconName") == entry["appIcon"], f"{entry['id']}: {family} primary icon does not match {entry['appIcon']}.")
        icons[family] = {"primaryIcon": primary, "pngFiles": png_files(primary, files, f"{entry['id']} {family}")}
    return {**entry, "installedInfo": {**expected, "CFBundleSupportedPlatforms": info["CFBundleSupportedPlatforms"]},
            "installedIcon": icons["CFBundleIcons"]["primaryIcon"], "installedIPadIcon": icons["CFBundleIcons~ipad"]["primaryIcon"],
            "compiledIcons": icons, "executable": executable}


def validate_app(app, entry, platform):
    info, files = read_app(app)
    record = check_variant(info, files, entry, platform)
    record.update(executableSHA256=sha256((app / record["executable"]).read_bytes()), assetCatalogSHA256=sha256((app / "Assets.car").read_bytes()))
    return record


def prepare(base, destination, entry, platform):
    evidence = inspect_base(base, [entry], platform)
    require(not destination.exists(), f"Output app already exists: {destination}.")
    require(not destination.resolve().is_relative_to(base.resolve()), "Output app must be outside the compiled base bundle.")
    info, _ = read_app(base)
    info.update(CFBundleIdentifier=entry["bundleIdentifier"], CFBundleDisplayName=entry["displayName"], ReveriePlaybackKind=entry["playbackKind"])
    for field, key in THEMES.items():
        info.pop(key, None)
        if field in entry:
            info[key] = entry[field]
    for key in ("CFBundleIconFiles", "CFBundleIconName"):
        info.pop(key, None)
    for family in FAMILIES:
        info[family] = {**info[family], "CFBundlePrimaryIcon": evidence["compiledIcons"][entry["id"]][family]["primaryIcon"]}
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(base, destination, symlinks=True)
    (destination / "Info.plist").write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
    record = validate_app(destination, entry, platform)
    for key in ("executableSHA256", "assetCatalogSHA256"):
        require(record[key] == evidence[key], f"{entry['id']}: compiled bytes changed during packaging ({key}).")
    return record


def validate_packages(directory, base, entries, platform):
    evidence = inspect_base(base, entries, platform)
    records = []
    for entry in entries:
        archive = directory / f"Reverie-{entry['id']}-unsigned.ipa"
        require(archive.is_file(), f"Missing unsigned package: {archive.name}.")
        with zipfile.ZipFile(archive) as payload:
            prefix = "Payload/Reverie.app/"
            files = {name.removeprefix(prefix) for name in payload.namelist() if name.startswith(prefix) and not name.endswith("/")}
            require("Info.plist" in files, f"{entry['id']}: IPA Info.plist missing.")
            record = check_variant(plistlib.loads(payload.read(prefix + "Info.plist")), files, entry, platform)
            hashes = {"executableSHA256": sha256(payload.read(prefix + record["executable"])), "assetCatalogSHA256": sha256(payload.read(prefix + "Assets.car"))}
            for key, value in hashes.items():
                require(value == evidence[key], f"{entry['id']}: IPA compiled bytes differ from base ({key}).")
        records.append({**entry, "file": archive.name, "sizeBytes": archive.stat().st_size, "sha256": sha256(archive.read_bytes()),
                        **hashes, "compiledIcons": record["compiledIcons"]})
    return {"generatedAt": datetime.now(timezone.utc).isoformat(), "platform": platform,
            "signing": "unsigned; Apple signing and provisioning required for installation",
            "packaging": "One compiled executable and icon catalog; per-app runtime Info.plist metadata",
            "sharedExecutableSHA256": evidence["executableSHA256"], "sharedAssetCatalogSHA256": evidence["assetCatalogSHA256"], "variants": records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "References/Branding/variants.json")
    commands = parser.add_subparsers(dest="command", required=True)
    listing = commands.add_parser("list")
    listing.add_argument("--only")
    listing.add_argument("--format", choices=("json", "tsv"), default="json")
    for name in ("inspect-base", "prepare", "validate", "validate-packages"):
        command = commands.add_parser(name)
        command.add_argument("--platform", choices=("iPhoneOS", "iPhoneSimulator"), required=True)
        command.add_argument("--output-json", type=Path, required=name == "validate-packages")
        if name == "validate":
            command.add_argument("--app", type=Path, required=True)
        else:
            command.add_argument("--base-app", type=Path, required=True)
        if name in ("prepare", "validate"):
            command.add_argument("--variant-id", required=True)
        else:
            command.add_argument("--only")
        if name == "prepare":
            command.add_argument("--output-app", type=Path, required=True)
        if name == "validate-packages":
            command.add_argument("--directory", type=Path, required=True)
    args = parser.parse_args()
    entries = select(load_variants(args.manifest), getattr(args, "only", None) or getattr(args, "variant_id", None))
    if args.command == "list":
        if args.format == "json":
            print(json.dumps(entries, indent=2))
        else:
            for entry in entries:
                print("\t".join(entry[key] for key in ("id", "displayName", "bundleIdentifier", "appIcon", "playbackKind")))
        return
    if args.command == "inspect-base":
        result = inspect_base(args.base_app, entries, args.platform)
        message = f"Verified {len(entries)} compiled alternate icons for {args.platform}."
    elif args.command == "prepare":
        result = prepare(args.base_app, args.output_app, entries[0], args.platform)
        message = f"Prepared {entries[0]['displayName']} from the shared compiled {args.platform} application."
    elif args.command == "validate":
        result = validate_app(args.app, entries[0], args.platform)
        message = f"Verified installed {entries[0]['displayName']} metadata, compiled icons, executable, and resources."
    else:
        result = validate_packages(args.directory, args.base_app, entries, args.platform)
        message = f"Verified {len(entries)} unsigned packages with the shared executable and icon catalog."
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(json.dumps(result, indent=2) + "\n")
    print(message)


if __name__ == "__main__":
    try:
        main()
    except (PackagingError, OSError, ValueError, KeyError, TypeError, AttributeError, zipfile.BadZipFile) as error:
        print(f"Brand packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
