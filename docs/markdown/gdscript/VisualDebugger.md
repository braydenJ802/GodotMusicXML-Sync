# VisualDebugger

**Inherits:** `Control`

## Brief Description
Interactive debugger and control surface for musically aware playback.

## Description
This UI displays current measure/beat state, upcoming cues, cue markers on a timeline, transport controls, loop controls, transition routing controls, transition style selection, song loading, and dynamic layer mute controls.

## Signals

### `queued_jump_requested(trigger_type: String, trigger_value: Variant, destination_type: String, destination_value: Variant)`
Emitted when the user requests a queued jump using the selected trigger and destination types.

### `immediate_jump_requested(destination_type: String, destination_value: Variant)`
Emitted when the user requests an immediate jump to the selected destination.

### `play_requested`
Emitted when the Play button is pressed.

### `pause_requested`
Emitted when the Pause button is pressed.

### `restart_requested`
Emitted when the Restart button is pressed.

### `loop_settings_requested(enabled: bool, start_measure: int, end_measure: int)`
Emitted when loop settings should be applied to playback.

### `song_load_requested(song_name: String)`
Emitted when the user chooses a different song preset to load.

### `transition_style_changed(style_name: String)`
Emitted when the selected transition style changes.

## Variables

### `clock_path: NodePath`
Optional exported path to a clock node, unused in the current scene-based wiring.

### `time_label: Label`
Label displaying the current measure and beat.

### `beat_flash: ColorRect`
Flashing rectangle used as a visual metronome pulse.

### `next_cue_label: Label`
Label displaying the next upcoming cue marker.

### `timeline_track: ColorRect`
Track area that holds cue markers and the playhead.

### `playhead: ColorRect`
Moving playhead that indicates current playback position along the timeline.

### `trigger_type_select: OptionButton`
Dropdown selecting whether the queued trigger is a cue or measure.

### `trigger_cue_select: OptionButton`
Dropdown of available cue names for queued trigger selection.

### `trigger_measure_spinbox: SpinBox`
SpinBox for queued trigger measure selection.

### `destination_type_select: OptionButton`
Dropdown selecting whether the queued destination is a measure or cue.

### `destination_measure_spinbox: SpinBox`
SpinBox for queued destination measure selection.

### `destination_cue_select: OptionButton`
Dropdown of available cue names for queued destination selection.

### `queue_jump_button: Button`
Main button for submitting a queued jump request.

### `immediate_destination_type_select: OptionButton`
Dropdown selecting whether the immediate destination is a measure or cue.

### `immediate_destination_measure_spinbox: SpinBox`
SpinBox for immediate destination measure selection.

### `immediate_destination_cue_select: OptionButton`
Dropdown of available cue names for immediate destination selection.

### `immediate_jump_button: Button`
Main button for submitting an immediate jump request.

### `jump_back_check: CheckBox`
Checkbox controlling whether repeated cue-name destinations resolve backward instead of forward.

### `play_button: Button`
Play transport button.

### `pause_button: Button`
Pause transport button.

### `restart_button: Button`
Restart transport button.

### `loop_enabled_check: CheckBox`
Checkbox enabling/disabling looping.

### `loop_start_spinbox: SpinBox`
Loop start measure control.

### `loop_end_spinbox: SpinBox`
Loop end measure control.

### `apply_loop_button: Button`
Button that applies the current loop settings.

### `transition_style_select: OptionButton`
Dropdown for selecting the default transition style.

### `song_select: OptionButton`
Dropdown for selecting which song preset is currently active.

### `load_song_button: Button`
Button that requests loading the selected song preset.

### `mute_layers_container: VBoxContainer`
Container that holds dynamically generated layer boxes and mute checkboxes.

### `song_data: SongData`
Parsed song data currently being visualized.

### `clock_ref: AudioClock`
Active clock reference currently being observed by the debugger.

### `music_director: MusicDirector`
Reference to the `MusicDirector` in the same scene.

### `total_song_time: float`
Total duration of the loaded song, in seconds.

### `current_measure: int`
Current measure being displayed, using 1-based numbering.

## Methods

### `_ready() -> void`
Initializes static UI signal wiring and gets a reference to the `MusicDirector`.

### `setup(clock: AudioClock) -> void`
Performs the initial debugger setup for a provided clock.

### `set_song_options(song_names: Array) -> void`
Populates the song preset dropdown with the provided names.

### `set_selected_song(song_name: String) -> void`
Selects the currently loaded song preset in the song dropdown.

### `set_transition_style(style_name: String) -> void`
Selects the current transition style in the transition-style dropdown.

### `_setup_jump_controls(offsets: PackedFloat32Array) -> void`
Configures transition and loop controls for the currently loaded song.

This populates cue dropdowns, initializes type selectors, and updates the visible widgets based on the currently selected trigger and destination modes.

### `refresh_for_new_song(clock: AudioClock) -> void`
Rebinds the debugger to a newly loaded song and rebuilds all song-dependent UI.

### `_rebuild_mute_layers() -> void`
Rebuilds the layer boxes and mute controls to match the currently loaded stem count.

### `_clear_mute_layers() -> void`
Removes all dynamically created layer boxes from the mute-layers container.

### `_on_dynamic_mute_toggled(toggled: bool, layer_index: int) -> void`
Handles dynamic mute-checkbox changes for a specific layer.

### `_get_layer_label(layer_index: int) -> String`
Returns the display label for a given layer index.

### `_get_layer_color(layer_index: int) -> Color`
Returns a color from the debugger palette for a given layer index.

### `_process(_delta) -> void`
Updates the playhead and end-of-song display state each frame.

### `_draw_cue_markers(offsets: PackedFloat32Array) -> void`
Draws vertical cue markers on the timeline using the current song’s cue data.

### `is_loop_enabled() -> bool`
Returns whether looping is currently enabled in the UI.

### `get_loop_start_measure() -> int`
Returns the currently selected loop start measure.

### `get_loop_end_measure() -> int`
Returns the currently selected loop end measure.

### `should_jump_back() -> bool`
Returns whether repeated cue resolution should prefer previous occurrences.

### `_on_play_button_pressed() -> void`
Emits a play request.

### `_on_pause_button_pressed() -> void`
Emits a pause request.

### `_on_restart_button_pressed() -> void`
Emits a restart request.

### `_on_apply_loop_button_pressed() -> void`
Emits the currently selected loop settings to be applied by the runtime.

### `_on_loop_enabled_toggled(enabled: bool) -> void`
Immediately disables looping when the loop-enabled checkbox is unchecked.

### `_on_queue_jump_button_pressed() -> void`
Emits a queued jump request using the currently selected trigger and destination controls.

### `_on_immediate_jump_button_pressed() -> void`
Emits an immediate jump request using the currently selected destination controls.

### `_on_beat(beat_number: int) -> void`
Updates the measure/beat display and flashes the visual metronome on each beat event.

### `_on_measure(measure_number: int) -> void`
Updates current measure display and computes the next upcoming cue.

### `_on_marker(marker_name: String) -> void`
Logs markers as they are passed by the clock.

### `_on_load_song_button_pressed() -> void`
Emits a request to load the currently selected song preset.

### `_connect_clock_signals() -> void`
Connects beat, measure, and marker signals from the active clock if they are not already connected.

### `_disconnect_clock_signals() -> void`
Disconnects beat, measure, and marker signals from the previously active clock.

### `_clear_timeline_markers() -> void`
Removes all cue markers from the timeline while preserving the playhead.

### `_update_transition_control_visibility() -> void`
Updates visibility of cue/measure controls based on the selected transition routing modes.

### `_on_transition_type_changed(_index: int) -> void`
Refreshes transition-control visibility when a type selector changes.

### `_on_transition_style_selected(index: int) -> void`
Emits a transition-style change when the Crossfade/Seamless selector changes.