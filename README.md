# Godot MusicXML-Sync

Godot MusicXML-Sync is a GDExtension for Godot 4 that parses MusicXML into runtime timing data and provides bar/beat/marker events for musically-aligned playback and transitions.

It’s designed to let you keep score-level timing information (tempo, measure boundaries, cue markers) available inside Godot so you can drive logic, visuals, and audio transitions using musical structure instead of raw timestamps.

## Features

- **MusicXML parsing** into a reusable `SongData` resource (tempo map, measure offsets, cue points)
- **Runtime clock** (`AudioClock`) that tracks song time and emits:
  - `beat(beat_number)`
  - `bar(bar_number)`
  - `marker_passed(marker_name)`
- **Transition control** (`TransitionManager`) for scheduling switches at bars or named markers
- **Works as a native GDExtension** (C++) for performance and editor integration

## Project Layout

- `src/` — C++ source for the extension
- `api/extension_api.json` — Godot extension API file used for building bindings
- `project/` — Example Godot project (contains `project.godot`)
- `project/bin/` — Built DLL + `.gdextension` file

## Building (Windows)

Prereqs:
- Python 3.x
- SCons
- A C++ toolchain (MSVC recommended)
- Godot 4.x `extension_api.json`

Build debug:
```powershell
py -m scons platform=windows target=template_debug custom_api_file=api/extension_api.json
```

Build release:
```powershell
py -m scons platform=windows target=template_release custom_api_file=api/extension_api.json
```

The compiled library is output to project/bin/.


## Using in Godot

1. Open the example project in `project/`.

2. Confirm the extension files are in `res://bin/`:
   - `godot_music_xml_sync.gdextension`
   - `godot_music_xml_sync.windows.template_debug.x86_64.dll` (debug)

3. Make sure `godot_music_xml_sync.gdextension` points to the correct library path(s), for example:
   ```ini
   [configuration]
   entry_symbol = "godot_music_xml_sync_library_init"
   reloadable = true

   [libraries]
   windows.editor.x86_64 = "res://bin/godot_music_xml_sync.windows.template_debug.x86_64.dll"
   windows.debug.x86_64  = "res://bin/godot_music_xml_sync.windows.template_debug.x86_64.dll"
   ```

4. Add an `AudioClock` node and assign a `SongData` resource.

5. Connect to signals (`bar`, `beat`, `marker_passed`) to drive game logic or transitions.


## License
MPL-2.0
