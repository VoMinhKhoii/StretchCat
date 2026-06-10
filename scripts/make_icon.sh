#!/usr/bin/env bash
# Build Resources/AppIcon.icns from Resources/AppIcon_1024.png
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/make_icon.py

SRC="Resources/AppIcon_1024.png"
SET="build/AppIcon.iconset"
rm -rf "$SET"; mkdir -p "$SET"

for sz in 16 32 128 256 512; do
    sips -z $sz $sz       "$SRC" --out "$SET/icon_${sz}x${sz}.png"      >/dev/null
    sips -z $((sz*2)) $((sz*2)) "$SRC" --out "$SET/icon_${sz}x${sz}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
