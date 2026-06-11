#!/usr/bin/env bash
#
# Build a drag-to-Applications DMG from build/StretchCat.app.
# Uses built-in hdiutil (no create-dmg dependency).
#
# If DEV_ID_APP + NOTARY_PROFILE are set, the DMG is signed, notarized, and
# stapled so it opens with no Gatekeeper warning on other Macs.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/StretchCat.app"
DMG="build/StretchCat.dmg"
RW="build/StretchCat-rw.dmg"
VOL="Stretch Cat"
STAGE="build/dmg-stage"
BG="Resources/dmg-background.tiff"

[ -d "$APP" ] || { echo "Build the app first: ./build.sh"; exit 1; }

# Detach any leftover "Stretch Cat" volume from a previous run — a stale mount
# shadows the fresh one at /Volumes/$VOL and silently breaks the layout pass.
for v in /Volumes/"$VOL"*; do
    [ -d "$v" ] && hdiutil detach "$v" -force >/dev/null 2>&1 || true
done

echo "==> Staging DMG contents"
rm -rf "$STAGE" "$DMG" "$RW"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# Background image lives in a hidden folder on the volume.
if [ -f "$BG" ]; then
    mkdir -p "$STAGE/.background"
    # HiDPI TIFF (1x + 2x reps) so the text stays crisp on retina displays.
    cp "$BG" "$STAGE/.background/background.tiff"
fi

echo "==> Creating writable DMG"
# Size with headroom over the app so the layout pass has room to write.
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW -fs HFS+ "$RW" >/dev/null
rm -rf "$STAGE"

echo "==> Arranging the drag-to-Applications window"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -E '^/dev/' | sed 1q | awk '{print $1}')
MOUNT="/Volumes/$VOL"
# Give the volume a moment to settle before scripting Finder.
sleep 1
osascript <<APPLESCRIPT || echo "   (Finder layout skipped — DMG still works)"
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        try
            set background picture of opts to file ".background:background.tiff"
        end try
        set position of item "StretchCat.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$DEVICE" >/dev/null

echo "==> Compressing DMG"
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -f "$RW"

if [ -n "${DEV_ID_APP:-}" ] && [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "==> Signing DMG"
    codesign --force --sign "$DEV_ID_APP" "$DMG"
    echo "==> Notarizing DMG (this can take a minute)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
else
    echo "NOTE: DEV_ID_APP / NOTARY_PROFILE not set — DMG is not notarized."
    echo "      Fine for local use; for public release see README 'Publishing'."
fi

echo "==> Done: $DMG"
shasum -a 256 "$DMG"
