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
VOL="Stretch Cat"
STAGE="build/dmg-stage"

[ -d "$APP" ] || { echo "Build the app first: ./build.sh"; exit 1; }

echo "==> Staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating compressed DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

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
