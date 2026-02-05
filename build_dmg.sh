#!/bin/bash
set -euo pipefail

# Build a self-contained UT99 macOS DMG by downloading all assets from scratch.
#
# Downloads the GOTY disc image from archive.org and the OldUnreal macOS patch
# from GitHub, then assembles everything into a drag-and-drop DMG.
#
# Configurable via environment variables:
#   OUTPUT_DIR   - Where to write the final DMG  (default: current directory)
#   DMG_NAME     - Base name for the DMG file    (default: UnrealTournament99-macOS)
#   CACHE_DIR    - Where to cache downloads      (default: ~/.cache/ut99-mac-packager)

OUTPUT_DIR="${OUTPUT_DIR:-.}"
DMG_NAME="${DMG_NAME:-UnrealTournament99-macOS}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/ut99-mac-packager}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGING="${SCRIPT_DIR}/${DMG_NAME}-staging"

APP_NAME="UnrealTournament"
BUNDLE="${STAGING}/${APP_NAME}.app"
MACOS="${BUNDLE}/Contents/MacOS"

# Sources
ISO_URL="https://archive.org/download/ut-goty/UT_GOTY_CD1.iso"
ISO_SHA256="e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f"
ISO_FILE="UT_GOTY_CD1.iso"

BP4_URL="https://files.oldunreal.net/utbonuspack4-zip.7z"
BP4_SHA256="5b7a1080724a122a596c226c50d4dc7c2d7636ceaf067e9c12112014a170ffba"
BP4_FILE="utbonuspack4-zip.7z"

PATCH_API="https://api.github.com/repos/OldUnreal/UnrealTournamentPatches/releases/latest"

cleanup() {
    # Unmount before removing staging
    if [ -n "${PATCH_MOUNT:-}" ]; then
        hdiutil detach "$PATCH_MOUNT" -force 2>/dev/null || true
    fi
    if [ -d "$STAGING" ]; then
        rm -rf "$STAGING"
    fi
}
trap cleanup EXIT

echo "=== UT99 macOS DMG Builder ==="

# Check dependencies
for cmd in curl 7z jq hdiutil codesign; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command not found: $cmd"
        if [ "$cmd" = "7z" ]; then
            echo "  Install with: brew install 7zip"
        elif [ "$cmd" = "jq" ]; then
            echo "  Install with: brew install jq"
        fi
        exit 1
    fi
done

mkdir -p "$CACHE_DIR"

# Download a file if not already cached (with SHA-256 verification if provided)
download() {
    local url="$1" dest="$2" expected_sha="${3:-}"

    if [ -f "$dest" ]; then
        if [ -n "$expected_sha" ]; then
            local actual_sha
            actual_sha=$(shasum -a 256 "$dest" | cut -d' ' -f1)
            if [ "$actual_sha" = "$expected_sha" ]; then
                echo "  Using cached: $(basename "$dest")"
                return 0
            fi
            echo "  Cached file has wrong checksum, re-downloading..."
            rm -f "$dest"
        else
            echo "  Using cached: $(basename "$dest")"
            return 0
        fi
    fi

    echo "  Downloading: $(basename "$dest")..."
    curl -L --progress-bar -o "$dest" "$url"

    if [ -n "$expected_sha" ]; then
        local actual_sha
        actual_sha=$(shasum -a 256 "$dest" | cut -d' ' -f1)
        if [ "$actual_sha" != "$expected_sha" ]; then
            echo "ERROR: SHA-256 mismatch for $(basename "$dest")"
            echo "  Expected: $expected_sha"
            echo "  Got:      $actual_sha"
            rm -f "$dest"
            exit 1
        fi
    fi
}

# Step 1: Download the GOTY disc image
echo ""
echo "--- Step 1: Download UT99 GOTY disc image ---"
download "$ISO_URL" "$CACHE_DIR/$ISO_FILE" "$ISO_SHA256"

# Step 2: Fetch latest macOS patch from GitHub releases
echo ""
echo "--- Step 2: Download OldUnreal macOS patch ---"
PATCH_INFO=$(curl -sL "$PATCH_API")
PATCH_URL=$(echo "$PATCH_INFO" | jq -r '.assets[] | select(.name | test("macOS"; "i")) | select(.name | test("Sonoma") | not) | .browser_download_url' | head -1)
PATCH_FILENAME=$(basename "$PATCH_URL")

if [ -z "$PATCH_URL" ] || [ "$PATCH_URL" = "null" ]; then
    echo "ERROR: Could not find macOS patch download URL from GitHub releases."
    echo "  Check: https://github.com/OldUnreal/UnrealTournamentPatches/releases"
    exit 1
fi

download "$PATCH_URL" "$CACHE_DIR/$PATCH_FILENAME"

echo ""
echo "--- Step 3: Download Bonus Pack 4 ---"
download "$BP4_URL" "$CACHE_DIR/$BP4_FILE" "$BP4_SHA256"

# Clean previous staging
if [ -d "$STAGING" ]; then
    rm -rf "$STAGING"
fi
mkdir -p "$STAGING"

# Step 3: Extract game data from ISO
echo ""
echo "--- Step 3: Extract game data from disc image ---"
ISO_EXTRACT="${STAGING}/iso-extract"
mkdir -p "$ISO_EXTRACT"
7z x -o"$ISO_EXTRACT" "$CACHE_DIR/$ISO_FILE" -y -bso0 -bsp0 \
    -x'!System/UnrealTournament.ini' \
    -x'!System/User.ini' \
    -x'!System/*.bat' \
    -x'!System/*.dll' \
    -x'!System/*.exe' \
    -x'!Autorun.inf' \
    -x'!Setup.exe' \
    -x'!DirectX7' \
    -x'!GameSpy' \
    -x'!Microsoft' \
    -x'!NetGamesUSA.com' \
    -x'!System400'
echo "  Extracted game data."

echo "  Extracting Bonus Pack 4..."
7z x -o"$ISO_EXTRACT" "$CACHE_DIR/$BP4_FILE" -y -bso0 -bsp0
echo "  Bonus Pack 4 extracted."

# Step 5: Mount patch DMG and copy app bundle
echo ""
echo "--- Step 4: Extract app bundle from macOS patch ---"
PATCH_MOUNT=$(mktemp -d /tmp/ut99-patch.XXXXXX)
hdiutil attach "$CACHE_DIR/$PATCH_FILENAME" -nobrowse -quiet -mountpoint "$PATCH_MOUNT"
echo "  Mounted patch DMG at: $PATCH_MOUNT"

# Find the .app bundle in the mounted DMG
PATCH_APP=$(find "$PATCH_MOUNT" -maxdepth 1 -name "*.app" -type d | head -1)
if [ -z "$PATCH_APP" ]; then
    echo "ERROR: No .app bundle found in patch DMG"
    exit 1
fi

echo "  Copying app bundle..."
cp -R "$PATCH_APP" "$BUNDLE"

hdiutil detach "$PATCH_MOUNT" -quiet
PATCH_MOUNT=""

# Step 5: Merge game data into the app bundle
echo ""
echo "--- Step 5: Merge game data into app bundle ---"
for dir in Maps Sounds Textures Music System Help; do
    if [ -d "$ISO_EXTRACT/$dir" ]; then
        mkdir -p "$MACOS/$dir"
        echo "  Copying $dir ($(du -sh "$ISO_EXTRACT/$dir" | cut -f1))..."
        # Use -n so ISO files never overwrite newer patch files
        cp -Rn "$ISO_EXTRACT/$dir/"* "$MACOS/$dir/" 2>/dev/null || true
    fi
done

# Step 6: Re-sign so UCC can run (adding files broke the original signature)
echo ""
echo "--- Step 6: Interim re-sign for UCC ---"
xattr -cr "$BUNDLE"
codesign --force --deep --sign - "$BUNDLE"

# Step 7: Decompress .uz map files using UCC
echo ""
echo "--- Step 7: Decompress map files ---"
UCC_BIN="$MACOS/UCC"
if [ -x "$UCC_BIN" ]; then
    UZ_COUNT=$(ls "$MACOS/Maps/"*.unr.uz 2>/dev/null | wc -l | tr -d ' ')
    if [ "$UZ_COUNT" -gt 0 ]; then
        echo "  Decompressing $UZ_COUNT map files..."
        CURRENT=0
        for uzfile in "$MACOS/Maps/"*.unr.uz; do
            [ -f "$uzfile" ] || continue
            CURRENT=$((CURRENT + 1))
            MAPNAME=$(basename "$uzfile")
            printf "  [%d/%d] %s\r" "$CURRENT" "$UZ_COUNT" "$MAPNAME"
            (cd "$MACOS/System" && "$UCC_BIN" decompress "../Maps/$MAPNAME" -nohomedir &>/dev/null) || {
                echo ""
                echo "WARNING: Failed to decompress $MAPNAME"
                continue
            }
            # UCC puts decompressed file in System, move it to Maps
            UNCOMPRESSED="${MAPNAME%.uz}"
            if [ -f "$MACOS/System/$UNCOMPRESSED" ]; then
                mv -f "$MACOS/System/$UNCOMPRESSED" "$MACOS/Maps/$UNCOMPRESSED"
            fi
            rm -f "$uzfile"
        done
        echo ""
        echo "  Maps decompressed."
    else
        echo "  No compressed maps found."
    fi

    # UT:GOTY fix — DM-Cybrosis][ doubles as DOM map
    if [ -f "$MACOS/Maps/DM-Cybrosis][.unr" ] && [ ! -f "$MACOS/Maps/DOM-Cybrosis][.unr" ]; then
        cp -f "$MACOS/Maps/DM-Cybrosis][.unr" "$MACOS/Maps/DOM-Cybrosis][.unr"
    fi
else
    echo "  WARNING: UCC not found, skipping map decompression."
fi

# Clean up ISO extract
rm -rf "$ISO_EXTRACT"

echo ""
echo "App bundle size: $(du -sh "$BUNDLE" | cut -f1)"

# Step 8: Final strip and re-sign
echo ""
echo "--- Step 8: Final sign ---"
echo "  Stripping extended attributes..."
xattr -cr "$BUNDLE"
echo "  Ad-hoc re-signing..."
codesign --force --deep --sign - "$BUNDLE"

# Step 9: Add Applications symlink for drag-and-drop install UX
ln -s /Applications "$STAGING/Applications"

# Step 10: Create compressed DMG
echo ""
echo "--- Step 9: Create DMG ---"
mkdir -p "$OUTPUT_DIR"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}.dmg"
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

echo "  Creating DMG (this may take a minute)..."
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
echo ""
echo "Build complete!"
