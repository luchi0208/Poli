#!/bin/bash
#
# generate-appcast.sh — Generate Sparkle appcast.xml from signed DMG releases.
#
# Usage:
#   ./scripts/generate-appcast.sh /path/to/releases
#
# Prerequisites:
#   1. One-time: Generate EdDSA keypair for Sparkle signing:
#        /path/to/Sparkle/bin/generate_keys
#      This prints your public key — add it to Info.plist as SUPublicEDKey.
#      The private key is stored in your Keychain automatically.
#
#   2. Place signed & notarized .dmg files in the releases directory.
#      Each DMG filename should include the version, e.g.:
#        WritingAssistant-1.0.dmg
#        WritingAssistant-1.1.dmg
#
#   3. Upload the generated appcast.xml to your update server:
#        az storage blob upload \
#          --container-name updates \
#          --file /path/to/releases/appcast.xml \
#          --name appcast.xml \
#          --content-type application/xml \
#          --overwrite
#

set -euo pipefail

RELEASES_DIR="${1:?Usage: $0 /path/to/releases}"

if [ ! -d "$RELEASES_DIR" ]; then
    echo "Error: Directory not found: $RELEASES_DIR"
    exit 1
fi

# Find generate_appcast in common locations
GENERATE_APPCAST=""
SEARCH_PATHS=(
    "/Applications/Sparkle.framework/Versions/Current/bin/generate_appcast"
    "$HOME/Library/Developer/Xcode/DerivedData/*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
    "$(xcode-select -p)/usr/bin/generate_appcast"
)

for path in "${SEARCH_PATHS[@]}"; do
    # Use globbing for wildcard paths
    for expanded in $path; do
        if [ -x "$expanded" ]; then
            GENERATE_APPCAST="$expanded"
            break 2
        fi
    done
done

if [ -z "$GENERATE_APPCAST" ]; then
    echo "Error: generate_appcast not found."
    echo "Install Sparkle or check DerivedData for the tool."
    echo ""
    echo "You can also run it directly from the Sparkle package:"
    echo "  swift package --package-path /path/to/Sparkle resolve"
    echo "  .build/artifacts/sparkle/Sparkle/bin/generate_appcast $RELEASES_DIR"
    exit 1
fi

echo "Using: $GENERATE_APPCAST"
echo "Releases dir: $RELEASES_DIR"
echo ""

"$GENERATE_APPCAST" "$RELEASES_DIR"

echo ""
echo "Done! appcast.xml generated in: $RELEASES_DIR"
echo ""
echo "Next steps:"
echo "  1. Upload appcast.xml to your update server"
echo "  2. Upload the DMG files to the same server"
echo "  3. Verify the download URLs in appcast.xml match your server"
