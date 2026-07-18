#!/bin/bash
# Regenerates Resources/AppIcon.icns from tools/make_icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
PNG="$TMP/icon_1024.png"
SET="$TMP/BatteryBar.iconset"

echo "→ Rendering 1024px PNG"
swift tools/make_icon.swift "$PNG"

echo "→ Building iconset"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$PNG" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$PNG" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
sips -z 1024 1024 "$PNG" --out "$SET/icon_512x512@2x.png" >/dev/null

echo "→ Converting to icns"
mkdir -p Resources
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$TMP"
echo "✓ Wrote Resources/AppIcon.icns"
