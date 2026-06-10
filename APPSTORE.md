# Publishing Stretch Cat to the Mac App Store

The App Store build is **sandboxed** and signed differently from the direct
download. `build-appstore.sh` produces the signed `.pkg`; the rest happens in
App Store Connect and can't be automated headlessly. This is the checklist.

## What the script does (automated)
- Sandboxed build (`StretchCat-appstore.entitlements`)
- Embeds your Mac App Store provisioning profile
- Signs the app with **Apple Distribution**
- Builds a signed installer `.pkg` with `productbuild`

## One-time setup in your Apple Developer account
1. **Register the App ID** `com.khoivo.stretchcat`
   (Certificates, IDs & Profiles → Identifiers → +).
2. **Create a Mac App Store provisioning profile** for that App ID; download it.
3. Make sure you have the **installer** certificate
   ("3rd Party Mac Developer Installer" or the current "Apple Distribution"
   installer cert). You already have *Apple Distribution* for the app itself.

## Build + upload
```bash
PROFILE=~/Downloads/StretchCat_AppStore.provisionprofile \
APP_CERT="Apple Distribution: Khoi Vo (ZNG57U88R5)" \
PKG_CERT="3rd Party Mac Developer Installer: Khoi Vo (ZNG57U88R5)" \
./build-appstore.sh

# Upload with an App Store Connect API key (Users and Access → Integrations → Keys)
xcrun altool --upload-app -f build/StretchCat-AppStore.pkg -t macos \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```
(You can also drag the `.pkg` into **Transporter.app**.)

## Finish in App Store Connect (manual — you do this)
1. **Create the app record**: My Apps → + → New App. Platform macOS,
   bundle ID `com.khoivo.stretchcat`, SKU `stretchcat`.
2. **Privacy**: Data collection = *No data collected* (the app stores only a
   couple of local preferences and never phones home).
3. **App info**: category *Health & Fitness* (or *Productivity*), description
   ("A friendly menu-bar reminder to stand up and stretch every two hours,
   starring an animated cat you can follow along with."), keywords, support URL.
4. **Screenshots** (required): run the app, open the dropdown and trigger a
   stretch, and capture the cat window + panel. Required size: 1280×800 or
   1440×900. (`⌘⇧4` then space to grab a window.)
5. Select the uploaded **build**, set price = Free, and **Submit for Review**.

Review typically takes 1–3 days. Notifications + a non-sandbox-breaking
menu-bar agent are App-Store-compliant, so approval should be straightforward.
