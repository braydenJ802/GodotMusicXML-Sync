# MusicDirector

**Inherits:** `Node`

## Brief Description
Coordinates score-aware playback, transitions, looping, and layered stem control.

## Description
`MusicDirector` acts as the main runtime controller for the demo. It loads `SongData` from MusicXML, manages synchronized audio stems, routes queued and immediate transitions through `TransitionManager`, and exposes transport and layer-muting controls for the UI.

## Variables

### `audio_clock: AudioClock`
Reference to the runtime musical clock that tracks playback state.

### `transition_manager: TransitionManager`
Reference to the transition scheduler that waits for measure/cue triggers.

### `song_data: SongData`
Parsed timing and cue data for the currently loaded song.

### `target_destination_measure: int`
Pending destination measure for the next transition request, using 1-based numbering.

### `stem_streams: Array[AudioStream]`
Audio stems currently assigned to the loaded song.

### `active_audio_group_players: Array[AudioStreamPlayer]`
Active synchronized playback groups currently alive in the scene.

Under normal playback this usually contains one player. During a transition it may briefly contain both the fading-out and fading-in group.

### `active_sync_streams: Array[AudioStreamSynchronized]`
Active synchronized stream resources corresponding to the current playback groups.

These are tracked so per-layer mute changes can be applied to active groups.

### `layer_volumes_db: Array[float]`
Target per-layer volumes in decibels for newly spawned synchronized groups.

This preserves mute state across transitions and restarts.

### `has_started_playback: bool`
Tracks whether playback has been started at least once in this session.

### `TransitionStyle`
Supported transition styles for musical jumps.

### `default_transition_style: int`
Default transition style for new requests, typically set by the loaded song preset.

### `pending_transition_style: int`
Style that should be used for the next queued or immediate transition.

## Methods

### `_ready() -> void`
Initializes signal wiring between the director, clock, and transition manager.

### `get_audio_clock() -> AudioClock`
Returns the `AudioClock` used by this director.

### `get_layer_count() -> int`
Returns the number of currently loaded audio layers/stems.

### `load_song(xml_path: String, audio_files: Array[AudioStream]) -> void`
Loads a MusicXML file and its corresponding stem audio into the runtime system.

`xml_path` is the resource path to the MusicXML file. `audio_files` contains the stem streams that should be synchronized for playback.

### `play_measures(start_measure: int, end_measure: int, should_loop: bool = false) -> void`
Starts playback from `start_measure`, optionally looping to `end_measure`.

Measure numbers are 1-based. If `should_loop` is `true`, the clock is configured to loop between the given measures.

### `play_full_song() -> void`
Starts playback from the beginning of the currently loaded song with looping disabled.

### `play_from_ui(loop_enabled: bool, start_measure: int, end_measure: int) -> void`
Handles the Play button behavior from the UI.

If playback is already running, this does nothing. If playback is paused, it resumes. Otherwise it starts or restarts playback using the current loop settings.

### `_has_paused_playback() -> bool`
Returns whether any active playback group is currently paused.

### `pause_music() -> void`
Pauses active audio playback and stops the clock from advancing.

### `resume_music() -> void`
Resumes active audio playback and resumes the clock without resetting song position.

### `stop_music() -> void`
Stops all active playback groups and resets transport state.

### `restart_from_ui(loop_enabled: bool, start_measure: int, end_measure: int) -> void`
Restarts playback from the beginning or from the active loop start based on UI settings.

### `set_loop_enabled(enabled: bool, start_measure: int = 1, end_measure: int = 2) -> void`
Enables or disables looping using 1-based measure boundaries.

### `request_jump_to_measure(wait_for_measure: int, destination_measure: int, style: int = -1) -> void`
Queues a transition that will trigger when playback reaches `wait_for_measure`.

Both `wait_for_measure` and `destination_measure` use 1-based numbering. `style` overrides the default transition style when not `-1`.

### `request_jump_to_marker(wait_marker: StringName, destination_measure: int, style: int = -1) -> void`
Queues a transition that will trigger when playback reaches `wait_marker`.

The destination is still expressed as a 1-based measure number.

### `request_immediate_jump_to_measure(destination_measure: int, style: int = -1) -> void`
Requests an immediate jump to `destination_measure` without waiting for a trigger.

### `request_jump_to_cue_from_measure(wait_for_measure: int, destination_marker: StringName, style: int = -1, jump_back: bool = false) -> void`
Queues a measure-triggered jump whose destination is resolved from a cue name.

If `jump_back` is `true`, repeated cue names resolve to the nearest previous occurrence. Otherwise they resolve to the nearest forward occurrence.

### `request_jump_to_cue_from_marker(wait_marker: StringName, destination_marker: StringName, style: int = -1, jump_back: bool = false) -> void`
Queues a cue-triggered jump whose destination is also resolved from a cue name.

### `request_immediate_jump_to_cue(destination_marker: StringName, style: int = -1, jump_back: bool = false) -> void`
Immediately jumps to a destination cue resolved relative to the current playback position.

### `set_default_transition_style(style_name: String) -> void`
Sets the default transition style used by future requests when no explicit override is provided.

Supported names are `"crossfade"` and `"seamless"`.

### `get_best_measure_for_cue(cue_name: StringName, prefer_forward: bool = true) -> int`
Resolves a cue name to the best matching destination measure relative to the current song position.

By default this prefers the nearest forward occurrence. If `prefer_forward` is `false`, it prefers the nearest previous occurrence.

### `set_layer_mute(index: int, is_muted: bool) -> void`
Smoothly mutes or unmutes a specific synchronized stem layer.

`index` is zero-based relative to the loaded stem array.

### `_on_loop_occurred(new_time: float) -> void`
Seeks all active playback groups back to the loop restart time emitted by the clock.

### `_on_transition_triggered(measure_number: int, marker_name: StringName) -> void`
Receives a trigger from `TransitionManager` and defers the actual transition execution.

### `_execute_transition(measure_number: int, marker_name: StringName) -> void`
Executes a pending musical transition to the currently stored destination measure.

The exact fade behavior depends on `pending_transition_style` and whether the request was immediate or queued.

### `_spawn_stem_group(start_time: float, fade_duration: float, fade_in_new_group: bool = true) -> void`
Creates a new synchronized playback group starting at `start_time` and hands it off to the crossfade system.

### `_build_synchronized_stream() -> AudioStreamSynchronized`
Builds an `AudioStreamSynchronized` resource from the currently loaded stem streams.

Current layer mute state is baked into the synchronized stream before playback begins.

### `_crossfade_groups(old_audio_players: Array[AudioStreamPlayer], new_audio_players: Array[AudioStreamPlayer], duration: float, fade_in_new_group: bool = true) -> void`
Crossfades or hands off from old playback groups to new playback groups.

If `duration` is zero or less, old groups are cut immediately and new groups are brought in at full volume. Otherwise old groups fade out, and new groups either fade in or enter at full volume depending on `fade_in_new_group`.

### `_set_layer_volume_for_active_streams(volume_db: float, index: int) -> void`
Applies an interpolated layer volume to all currently tracked synchronized streams.
'''
docs['gdscript/main.md'] = '''# main.gd

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