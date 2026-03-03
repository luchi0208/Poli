#!/bin/bash
set -euo pipefail

# WritingAssistant DMG Creation Script
# Creates a distributable .dmg with drag-to-install layout

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Poli"
DMG_NAME="Poli"
APP_PATH="${1:-$BUILD_DIR/export/$APP_NAME.app}"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
TEMP_DMG="$BUILD_DIR/$DMG_NAME-temp.dmg"
VOLUME_NAME="Poli"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    echo "Usage: $0 [path/to/WritingAssistant.app]"
    echo ""
    echo "If you haven't built yet, run:"
    echo "  scripts/notarize.sh  (for signed+notarized build)"
    echo "  or build from Xcode first"
    exit 1
fi

# Get version from app
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_PATH="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"

echo "=== Creating DMG for $APP_NAME v$VERSION ==="

# Clean up previous
rm -f "$TEMP_DMG" "$DMG_PATH"

# Create temp DMG
echo "Creating temporary DMG..."
hdiutil create \
    -size 100m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    "$TEMP_DMG"

# Mount
echo "Mounting..."
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" | grep "/Volumes/" | awk '{print $3}')

# Copy app
echo "Copying app..."
ditto "$APP_PATH" "$MOUNT_DIR/$(basename "$APP_PATH")"

# Create Applications symlink
ln -s /Applications "$MOUNT_DIR/Applications"

# Set icon layout using AppleScript
echo "Setting window layout..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 900, 500}
        set arrangement of icon view options of container window to not arranged
        set icon size of icon view options of container window to 80
        set position of item "$APP_NAME.app" of container window to {120, 150}
        set position of item "Applications" of container window to {380, 150}
        close
    end tell
end tell
APPLESCRIPT

# Unmount
echo "Unmounting..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed, read-only DMG
echo "Converting to final DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up temp
rm -f "$TEMP_DMG"

echo ""
echo "Done! DMG created at: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
