# main.gd

**Inherits:** `Node`

## Brief Description
Demo scene coordinator that connects the UI to the playback runtime.

## Description
This script defines song presets, loads MusicXML plus audio stem bundles, and routes `VisualDebugger` requests into `MusicDirector`.

## Variables

### `music_director: MusicDirector`
Reference to the scene’s central playback coordinator.

### `visual_debugger: VisualDebugger`
Reference to the in-engine debugger/control surface UI.

### `song_presets: Dictionary`
Dictionary of demo song presets.

Each preset defines a MusicXML file, a list of synchronized audio stem paths, and a default transition style used when the preset is loaded.

## Methods

### `_ready() -> void`
Initializes the demo scene, hooks up UI signals, and loads the default song preset.

### `_load_song_preset(song_name: String) -> void`
Loads a song preset by name, including MusicXML, stem audio, and default transition style.

### `_on_song_load_requested(song_name: String) -> void`
Handles a request from the UI to load a different song preset.

### `_on_queued_jump_requested(trigger_type: String, trigger_value: Variant, destination_type: String, destination_value: Variant) -> void`
Routes a queued jump request from the UI to the correct `MusicDirector` method.

Trigger and destination may each be a cue or a measure. Cue destinations can optionally resolve backward depending on the debugger’s Jump Back checkbox.

### `_on_immediate_jump_requested(destination_type: String, destination_value: Variant) -> void`
Routes an immediate jump request from the UI to the correct `MusicDirector` method.

### `_on_play_requested() -> void`
Handles the Play button using the loop settings currently displayed in the debugger.

### `_on_pause_requested() -> void`
Handles the Pause button.

### `_on_restart_requested() -> void`
Handles the Restart button using the loop settings currently displayed in the debugger.

### `_on_loop_settings_requested(enabled: bool, start_measure: int, end_measure: int) -> void`
Applies loop settings requested by the debugger UI.

### `_on_transition_style_changed(style_name: String) -> void`
Applies a new default transition style selected from the debugger UI.