#!/usr/bin/env bash
#
# Build a sandboxed, App-Store-signed .pkg ready to upload to App Store Connect.
#
# Prerequisites (one-time, in your Apple Developer account):
#   1. Register the App ID  com.khoivo.stretchcat  (Certificates, IDs & Profiles)
#   2. Create a "Mac App Store" provisioning profile for it; download it.
#   3. Have these certs in your keychain:
#        - "Apple Distribution: Khoi Vo (ZNG57U88R5)"        (you have this)
#        - "3rd Party Mac Developer Installer" OR "Apple Distribution" installer
#
# Then:
#   PROFILE=/path/to/StretchCat_AppStore.provisionprofile \
#   APP_CERT="Apple Distribution: Khoi Vo (ZNG57U88R5)" \
#   PKG_CERT="3rd Party Mac Developer Installer: Khoi Vo (ZNG57U88R5)" \
#   ./build-appstore.sh
#
# Finish in App Store Connect — see APPSTORE.md.
set -euo pipefail
cd "$(dirname "$0")"

: "${PROFILE:?set PROFILE to your .provisionprofile path}"
: "${APP_CERT:?set APP_CERT to your Apple Distribution identity}"
: "${PKG_CERT:?set PKG_CERT to your installer signing identity}"

# 1. Build the app bundle (icon + resources) via the normal script, unsigned.
./build.sh -

APP="build/StretchCat.app"

# 2. Embed the provisioning profile.
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

# 3. Sign with sandbox entitlements (App Store requires the sandbox).
echo "==> Signing for App Store"
codesign --force --options runtime --timestamp \
    --entitlements StretchCat-appstore.entitlements \
    --sign "$APP_CERT" "$APP"

# 4. Build the installer package.
echo "==> Building signed .pkg"
xcrun productbuild --component "$APP" /Applications \
    --sign "$PKG_CERT" build/StretchCat-AppStore.pkg

echo ""
echo "✅ build/StretchCat-AppStore.pkg"
echo "Validate + upload:"
echo "  xcrun altool --validate-app -f build/StretchCat-AppStore.pkg -t macos \\"
echo "    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "  xcrun altool --upload-app   -f build/StretchCat-AppStore.pkg -t macos \\"
echo "    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "Then complete the listing in App Store Connect — see APPSTORE.md."
