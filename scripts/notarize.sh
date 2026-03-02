#!/bin/bash
set -euo pipefail

# WritingAssistant Notarization Script
# Prerequisites:
#   - Apple Developer account with Developer ID Application certificate
#   - Set environment variables:
#     DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
#     APPLE_ID="your@email.com"
#     APP_PASSWORD="app-specific-password"  (generate at appleid.apple.com)
#     TEAM_ID="YOUR_TEAM_ID"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="WritingAssistant"
SCHEME="WritingAssistant"

# Check required env vars
if [ -z "${DEVELOPER_ID:-}" ]; then
    echo "Error: Set DEVELOPER_ID environment variable"
    echo "Example: export DEVELOPER_ID=\"Developer ID Application: Your Name (TEAMID)\""
    exit 1
fi

if [ -z "${APPLE_ID:-}" ] || [ -z "${APP_PASSWORD:-}" ] || [ -z "${TEAM_ID:-}" ]; then
    echo "Error: Set APPLE_ID, APP_PASSWORD, and TEAM_ID environment variables"
    exit 1
fi

echo "=== Building archive ==="
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    CODE_SIGN_STYLE=Manual \
    ENABLE_HARDENED_RUNTIME=YES

echo "=== Exporting archive ==="

# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/export"

APP_PATH="$BUILD_DIR/export/$APP_NAME.app"

echo "=== Submitting for notarization ==="
xcrun notarytool submit "$APP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

echo "=== Stapling notarization ticket ==="
xcrun stapler staple "$APP_PATH"

echo "=== Verifying ==="
spctl --assess --type execute --verbose "$APP_PATH"

echo ""
echo "Done! Notarized app is at: $APP_PATH"
echo "Next: Run scripts/create-dmg.sh to package as DMG"
