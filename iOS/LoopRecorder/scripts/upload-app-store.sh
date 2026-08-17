#!/usr/bin/env bash
# Build, export, and upload LoopRecorder to App Store Connect.
# Requires ONE of:
#   1. App Store Connect API key env vars (recommended):
#        export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXX.p8"
#        export APP_STORE_CONNECT_API_KEY_ID="XXXXXX"
#        export APP_STORE_CONNECT_API_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   2. Apple ID app-specific password:
#        export FASTLANE_USER="tsy0110@icloud.com"
#        export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building and uploading via fastlane..."
fastlane release "$@"
