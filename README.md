# ut99-mac-packager

Build a distributable macOS DMG for Unreal Tournament 99.

## Prerequisites

- macOS
- UT99 installed via the [OldUnreal](https://www.oldunreal.com/) patch (469d or later)
- The app bundle at `/Applications/UnrealTournament.app` and game data in `~/Library/Application Support/Unreal Tournament/`

## Usage

```bash
./build_dmg.sh
```

The DMG is written to the current directory by default. Override paths with environment variables:

```bash
APP_SRC=/path/to/UnrealTournament.app \
DATA_SRC=/path/to/game-data \
OUTPUT_DIR=~/Desktop \
./build_dmg.sh
```

| Variable     | Default                                                  | Description                    |
|--------------|----------------------------------------------------------|--------------------------------|
| `APP_SRC`    | `/Applications/UnrealTournament.app`                     | Path to the app bundle         |
| `DATA_SRC`   | `~/Library/Application Support/Unreal Tournament`        | Path to game data directory    |
| `OUTPUT_DIR` | `.` (current directory)                                  | Where to write the DMG         |
| `DMG_NAME`   | `UnrealTournament99-macOS`                               | Base filename for the DMG      |

## What the DMG contains

- A self-contained `UnrealTournament.app` with all Maps, Sounds, Textures, and Music baked in
- An `Applications` shortcut for drag-and-drop installation

The bundle is ad-hoc code-signed so macOS will allow it to run.

## First launch

The app is not notarized, so macOS will block it on first open. Right-click the app and choose **Open**, then confirm in the dialog.

## License

MIT
