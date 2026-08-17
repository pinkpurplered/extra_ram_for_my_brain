# Publishing to the App Store

## Current status

| Step | Status |
|------|--------|
| Paid Apple Developer account | Done (Team **Sin Yu Ting**, `75R8BQ422C`) |
| Bundle ID | `com.extraram.LoopRecorder` |
| Release archive + IPA export | Done (Apple Distribution signed) |
| App Store Connect upload | Ready — waiting on app record in ASC |
| App Store listing (screenshots, review) | Not started |

## One-time: App Store Connect API key (recommended)

1. Open [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Create a key with **App Manager** access. Download the `.p8` file (only shown once).
3. Save it and export:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_D8WLYCSLX9.p8 ~/.appstoreconnect/private_keys/
export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_D8WLYCSLX9.p8"
export APP_STORE_CONNECT_API_KEY_ID="D8WLYCSLX9"
export APP_STORE_CONNECT_API_ISSUER_ID="777189c3-31c7-4d39-9135-fa3d520d3162"
```

Add those three `export` lines to `~/.zshrc` so future shells have them.

**Note:** Individual API keys can upload builds and update listings, but Apple does not allow them to *create* new app records via API. Create the app once in the App Store Connect web UI (see below), then use the scripts.

## Publish (automated)

From `iOS/LoopRecorder/`:

```bash
# First time only — creates the App Store Connect app record
fastlane create_app

# Upload metadata (description, keywords, etc.)
fastlane metadata

# Build + upload binary
./scripts/upload-app-store.sh

# After filling age rating & screenshots in App Store Connect:
fastlane submit
```

## iCloud Drive (saved clips)

Saved clips are stored in **iCloud → Recall Audio**. iCloud is enabled on the bundle ID via App Store Connect API; Xcode automatic signing picks up the updated provisioning profile on build.

## Manual steps in App Store Connect

After the build uploads, open [App Store Connect](https://appstoreconnect.apple.com) and complete:

1. **App Information** — category, content rights, age rating questionnaire.
2. **Pricing** — free or paid.
3. **App Privacy** — declare **Microphone** usage (audio recording, not linked to identity).
4. **Screenshots** — at minimum iPhone 6.7" (1290×2796). Capture on a real device or simulator, or add PNGs under `fastlane/metadata/en-US/screenshots/`.
5. **Version 1.0** — select the uploaded build, add “What’s New”, then submit for review.

## Privacy policy

Apple requires a privacy policy URL when collecting microphone data. Replace the placeholder in `fastlane/metadata/en-US/privacy_url.txt` with a real page before submission.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in `Config/Info.plist` (standard HTTPS only).

## Rebuild only (no upload)

```bash
xcodebuild -scheme LoopRecorder -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/LoopRecorder.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive \
  -archivePath /tmp/LoopRecorder.xcarchive \
  -exportPath /tmp/LoopRecorder-export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

The IPA is at `/tmp/LoopRecorder-export/LoopRecorder.ipa`.
