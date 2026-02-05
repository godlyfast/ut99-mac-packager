#!/bin/bash
set -euo pipefail

# Build a self-contained UT99 macOS DMG from installed files.
#
# Configurable via environment variables:
#   APP_SRC      - Path to UnrealTournament.app (default: /Applications/UnrealTournament.app)
#   DATA_SRC     - Path to game data directory   (default: ~/Library/Application Support/Unreal Tournament)
#   OUTPUT_DIR   - Where to write the final DMG  (default: current directory)
#   DMG_NAME     - Base name for the DMG file    (default: UnrealTournament99-macOS)

APP_NAME="UnrealTournament"
APP_SRC="${APP_SRC:-/Applications/${APP_NAME}.app}"
DATA_SRC="${DATA_SRC:-$HOME/Library/Application Support/Unreal Tournament}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
DMG_NAME="${DMG_NAME:-UnrealTournament99-macOS}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGING="${SCRIPT_DIR}/${DMG_NAME}-staging"
BUNDLE="${STAGING}/${APP_NAME}.app"
MACOS="${BUNDLE}/Contents/MacOS"

echo "=== UT99 macOS DMG Builder ==="

# Validate sources exist
for dir in "$APP_SRC" "$DATA_SRC/Maps" "$DATA_SRC/Sounds" "$DATA_SRC/Textures" "$DATA_SRC/Music"; do
    if [ ! -d "$dir" ]; then
        echo "ERROR: Required directory not found: $dir"
        exit 1
    fi
done

# Clean previous staging
if [ -d "$STAGING" ]; then
    echo "Removing previous staging directory..."
    rm -rf "$STAGING"
fi

mkdir -p "$STAGING"

# Step 1: Copy app bundle
echo "Copying app bundle..."
cp -R "$APP_SRC" "$BUNDLE"

# Step 2: Copy game data into the bundle
echo "Copying Maps ($(du -sh "$DATA_SRC/Maps" | cut -f1))..."
cp "$DATA_SRC/Maps/"* "$MACOS/Maps/"

echo "Copying Sounds ($(du -sh "$DATA_SRC/Sounds" | cut -f1))..."
cp "$DATA_SRC/Sounds/"* "$MACOS/Sounds/"

echo "Copying Textures ($(du -sh "$DATA_SRC/Textures" | cut -f1))..."
cp "$DATA_SRC/Textures/"* "$MACOS/Textures/"

echo "Copying Music ($(du -sh "$DATA_SRC/Music" | cut -f1))..."
cp "$DATA_SRC/Music/"* "$MACOS/Music/"

echo "App bundle size: $(du -sh "$BUNDLE" | cut -f1)"

# Step 3: Strip quarantine/extended attributes and ad-hoc re-sign
echo "Stripping extended attributes..."
xattr -cr "$BUNDLE"
echo "Ad-hoc re-signing app bundle..."
codesign --force --deep --sign - "$BUNDLE"

# Step 4: Add Applications symlink for drag-and-drop install UX
ln -s /Applications "$STAGING/Applications"

# Step 5: Create compressed DMG
mkdir -p "$OUTPUT_DIR"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
if [ -f "$DMG_PATH" ]; then
    echo "Removing previous DMG..."
    rm "$DMG_PATH"
fi

echo "Creating DMG (this may take a minute)..."
hdiutil create \
    -volname "Unreal Tournament 99" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_PATH"
echo "Size: $(du -sh "$DMG_PATH" | cut -f1)"

# Cleanup staging
echo "Cleaning up staging directory..."
rm -rf "$STAGING"

echo "Build complete!"
