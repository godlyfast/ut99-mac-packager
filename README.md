# ut99-mac-packager

Build a distributable macOS DMG for Unreal Tournament 99. Downloads everything automatically — no prior installation needed.

## For players

The DMG is fully self-contained — just drag `UnrealTournament.app` to Applications and play. No installer, no extra downloads, no dependencies. All Maps, Sounds, Textures, and Music are baked into the app bundle.

On first launch, macOS will block the app because it isn't notarized. Right-click the app, choose **Open**, and confirm the dialog. After that it runs normally.

## Building the DMG

### Prerequisites

- macOS
- [Homebrew](https://brew.sh/) dependencies: `brew install 7zip jq`

### Usage

```bash
./build_dmg.sh
```

The script will:
1. Download the UT99 GOTY disc image from [archive.org](https://archive.org/details/ut-goty) (~620 MB, cached)
2. Download the latest [OldUnreal](https://github.com/OldUnreal/UnrealTournamentPatches) macOS patch from GitHub
3. Extract game data from the disc image
4. Assemble the app bundle with all Maps, Sounds, Textures, and Music
5. Decompress map files
6. Ad-hoc code-sign the bundle
7. Package everything into a compressed DMG

Downloads are cached in `~/.cache/ut99-mac-packager/` so subsequent builds are fast.

### Configuration

| Variable     | Default                          | Description                    |
|--------------|----------------------------------|--------------------------------|
| `OUTPUT_DIR` | `.` (current directory)          | Where to write the DMG         |
| `DMG_NAME`   | `UnrealTournament99-macOS`       | Base filename for the DMG      |
| `CACHE_DIR`  | `~/.cache/ut99-mac-packager`     | Where to cache downloads       |

```bash
OUTPUT_DIR=~/Desktop ./build_dmg.sh
```

## What the DMG contains

- A self-contained `UnrealTournament.app` with all game data included
- An `Applications` shortcut for drag-and-drop installation

The bundle is ad-hoc code-signed so macOS will allow it to run.

## License

MIT
