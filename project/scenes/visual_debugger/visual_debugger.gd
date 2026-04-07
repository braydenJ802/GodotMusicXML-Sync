class_name VisualDebugger
extends Control
## Interactive debugger and control surface for musically aware playback.
##
## This UI displays current measure/beat state, upcoming cues, cue markers on a
## timeline, transport controls, loop controls, transition routing controls,
## transition style selection, song loading, and dynamic layer mute controls.

## Emitted when the user requests a queued jump using the selected trigger and destination types.
signal queued_jump_requested(trigger_type: String, trigger_value: Variant, destination_type: String, destination_value: Variant)
## Emitted when the user requests an immediate jump to the selected destination.
signal immediate_jump_requested(destination_type: String, destination_value: Variant)
## Emitted when the Play button is pressed.
signal play_requested
## Emitted when the Pause button is pressed.
signal pause_requested
## Emitted when the Restart button is pressed.
signal restart_requested
## Emitted when loop settings should be applied to playback.
signal loop_settings_requested(enabled: bool, start_measure: int, end_measure: int)
## Emitted when the user chooses a different song preset to load.
signal song_load_requested(song_name: String)
## Emitted when the selected transition style changes.
signal transition_style_changed(style_name: String)

## Optional exported path to a clock node, unused in the current scene-based wiring.
@export var clock_path: NodePath

## Label displaying the current measure and beat.
@onready var time_label: Label = $MusicalDisplay/%TimeLabel
## Flashing rectangle used as a visual metronome pulse.
@onready var beat_flash: ColorRect = $MusicalDisplay/%BeatFlash
## Label displaying the next upcoming cue marker.
@onready var next_cue_label: Label = $MusicalDisplay/%NextCueLabel

## Track area that holds cue markers and the playhead.
@onready var timeline_track: ColorRect = $Timeline/%TimelineTrack
## Moving playhead that indicates current playback position along the timeline.
@onready var playhead: ColorRect = $Timeline/%PlayHead

## Dropdown selecting whether the queued trigger is a cue or measure.
@onready var trigger_type_select: OptionButton = $TransitionOptions/%TriggerTypeSelect
## Dropdown of available cue names for queued trigger selection.
@onready var trigger_cue_select: OptionButton = $TransitionOptions/%TriggerCueSelect
## SpinBox for queued trigger measure selection.
@onready var trigger_measure_spinbox: SpinBox = $TransitionOptions/%TriggerMeasureSpinBox

## Dropdown selecting whether the queued destination is a measure or cue.
@onready var destination_type_select: OptionButton = $TransitionOptions/%DestinationTypeSelect
## SpinBox for queued destination measure selection.
@onready var destination_measure_spinbox: SpinBox = $TransitionOptions/%DestinationMeasureSpinBox
## Dropdown of available cue names for queued destination selection.
@onready var destination_cue_select: OptionButton = $TransitionOptions/%DestinationCueSelect

## Main button for submitting a queued jump request.
@onready var queue_jump_button: Button = $TransitionOptions/%QueueJumpButton

## Dropdown selecting whether the immediate destination is a measure or cue.
@onready var immediate_destination_type_select: OptionButton = $TransitionOptions/%ImmediateDestinationTypeSelect
## SpinBox for immediate destination measure selection.
@onready var immediate_destination_measure_spinbox: SpinBox = $TransitionOptions/%ImmediateDestinationMeasureSpinBox
## Dropdown of available cue names for immediate destination selection.
@onready var immediate_destination_cue_select: OptionButton = $TransitionOptions/%ImmediateDestinationCueSelect

## Main button for submitting an immediate jump request.
@onready var immediate_jump_button: Button = $TransitionOptions/%ImmediateJumpButton

## Checkbox controlling whether repeated cue-name destinations resolve backward instead of forward.
@onready var jump_back_check: CheckBox = $TransitionOptions/%JumpBackCheckBox

## Play transport button.
@onready var play_button: Button = $PlayerOptions/%PlayButton
## Pause transport button.
@onready var pause_button: Button = $PlayerOptions/%PauseButton
## Restart transport button.
@onready var restart_button: Button = $PlayerOptions/%RestartButton
## Checkbox enabling/disabling looping.
@onready var loop_enabled_check: CheckBox = $PlayerOptions/%LoopEnabledCheckBox
## Loop start measure control.
@onready var loop_start_spinbox: SpinBox = $PlayerOptions/%LoopStartSpinBox
## Loop end measure control.
@onready var loop_end_spinbox: SpinBox = $PlayerOptions/%LoopEndSpinBox
## Button that applies the current loop settings.
@onready var apply_loop_button: Button = $PlayerOptions/%ApplyLoopButton
## Dropdown for selecting the default transition style.
@onready var transition_style_select: OptionButton = $PlayerOptions/%TransitionStyleSelect

## Dropdown for selecting which song preset is currently active.
@onready var song_select: OptionButton = $SongOptions/%SongSelect
## Button that requests loading the selected song preset.
@onready var load_song_button: Button = $SongOptions/%LoadSongButton

## Container that holds dynamically generated layer boxes and mute checkboxes.
@onready var mute_layers_container: VBoxContainer = $Timeline/%MuteLayers

## Parsed song data currently being visualized.
var song_data: SongData
## Active clock reference currently being observed by the debugger.
var clock_ref: AudioClock
## Reference to the [MusicDirector] in the same scene.
var music_director: MusicDirector
## Total duration of the loaded song, in seconds.
var total_song_time: float = 0.0
## Current measure being displayed, using 1-based numbering.
var current_measure: int = 0

## Initializes static UI signal wiring and gets a reference to the [MusicDirector].
func _ready():
	beat_flash.modulate.a = 0.0
	
	music_director = get_parent().get_node("MusicDirector")
	
	queue_jump_button.pressed.connect(_on_queue_jump_button_pressed)
	immediate_jump_button.pressed.connect(_on_immediate_jump_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	apply_loop_button.pressed.connect(_on_apply_loop_button_pressed)
	loop_enabled_check.toggled.connect(_on_loop_enabled_toggled)
	load_song_button.pressed.connect(_on_load_song_button_pressed)
	trigger_type_select.item_selected.connect(_on_transition_type_changed)
	destination_type_select.item_selected.connect(_on_transition_type_changed)
	immediate_destination_type_select.item_selected.connect(_on_transition_type_changed)

	transition_style_select.clear()
	transition_style_select.add_item("Crossfade")
	transition_style_select.add_item("Seamless")
	transition_style_select.item_selected.connect(_on_transition_style_selected)

## Performs the initial debugger setup for a provided clock.
func setup(clock: AudioClock):
	refresh_for_new_song(clock)

## Populates the song preset dropdown with the provided names.
func set_song_options(song_names: Array):
	song_select.clear()

	var sorted_names: Array[String] = []
	for name: String in song_names:
		sorted_names.append(str(name))
	sorted_names.sort()

	for name in sorted_names:
		song_select.add_item(name)

## Selects the currently loaded song preset in the song dropdown.
func set_selected_song(song_name: String):
	for i in range(song_select.item_count):
		if song_select.get_item_text(i) == song_name:
			song_select.select(i)
			return

## Selects the current transition style in the transition-style dropdown.
func set_transition_style(style_name: String):
	for i in range(transition_style_select.item_count):
		if transition_style_select.get_item_text(i).to_lower() == style_name.to_lower():
			transition_style_select.select(i)
			return

## Configures transition and loop controls for the currently loaded song.
##
## This populates cue dropdowns, initializes type selectors, and updates the
## visible widgets based on the currently selected trigger/destination modes.
func _setup_jump_controls(offsets: PackedFloat32Array):
	trigger_type_select.clear()
	trigger_type_select.add_item("Cue")
	trigger_type_select.add_item("Measure")

	destination_type_select.clear()
	destination_type_select.add_item("Measure")
	destination_type_select.add_item("Cue")

	immediate_destination_type_select.clear()
	immediate_destination_type_select.add_item("Measure")
	immediate_destination_type_select.add_item("Cue")

	trigger_cue_select.clear()
	destination_cue_select.clear()
	immediate_destination_cue_select.clear()

	var cues_by_name: Dictionary = song_data.get_cues_by_name()
	var cue_names: Array = cues_by_name.keys()
	cue_names.sort()

	for cue_name in cue_names:
		var text := String(cue_name)
		trigger_cue_select.add_item(text)
		destination_cue_select.add_item(text)
		immediate_destination_cue_select.add_item(text)

	var max_measure: int = max(1, offsets.size() - 1)

	trigger_measure_spinbox.min_value = 1
	trigger_measure_spinbox.max_value = max_measure
	trigger_measure_spinbox.step = 1
	trigger_measure_spinbox.value = 1

	destination_measure_spinbox.min_value = 1
	destination_measure_spinbox.max_value = max_measure
	destination_measure_spinbox.step = 1
	destination_measure_spinbox.value = 1

	immediate_destination_measure_spinbox.min_value = 1
	immediate_destination_measure_spinbox.max_value = max_measure
	immediate_destination_measure_spinbox.step = 1
	immediate_destination_measure_spinbox.value = 1
	
	loop_start_spinbox.min_value = 1
	loop_start_spinbox.max_value = max_measure
	loop_start_spinbox.step = 1
	loop_start_spinbox.value = 1

	loop_end_spinbox.min_value = 1
	loop_end_spinbox.max_value = max_measure
	loop_end_spinbox.step = 1
	loop_end_spinbox.value = min(6, max_measure)

	_update_transition_control_visibility()

## Rebinds the debugger to a newly loaded song and rebuilds all song-dependent UI.
func refresh_for_new_song(clock: AudioClock) -> void:
	_disconnect_clock_signals()
	_clear_timeline_markers()
	
	clock_ref = clock
	song_data = clock.get_song_data()
	current_measure = 0
	total_song_time = 0.0
	
	beat_flash.modulate.a = 0.0
	time_label.text = "Measure: -- Beat: --"
	next_cue_label.text = "Upcoming Cue: --"
	playhead.anchor_left = 0.0
	playhead.anchor_right = 0.0
	play_button.text = "Play"
	
	_rebuild_mute_layers()
	_connect_clock_signals()

	var offsets: PackedFloat32Array = song_data.get_measure_offsets()
	if offsets.size() > 0:
		total_song_time = offsets[offsets.size() - 1]
		_draw_cue_markers(offsets)
		_setup_jump_controls(offsets)

## Rebuilds the layer boxes and mute controls to match the currently loaded stem count.
func _rebuild_mute_layers() -> void:
	_clear_mute_layers()
	
	if music_director == null:
		return
	
	var layer_count: int = music_director.get_layer_count()
	print("Rebuilding mute layers. Count = ", layer_count)
	
	for i in range(layer_count):
		var layer_row: ColorRect = ColorRect.new()
		layer_row.name = "StemInstrument%d" % (i + 1)
		layer_row.custom_minimum_size = Vector2(0, 80)
		layer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layer_row.color = _get_layer_color(i)
		
		var margin: MarginContainer = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.offset_left = 8
		margin.offset_top = 8
		margin.offset_right = -8
		margin.offset_bottom = -8
		layer_row.add_child(margin)
		
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = 0
		vbox.size_flags_vertical = 0
		margin.add_child(vbox)
		
		var label: Label = Label.new()
		label.name = "Label"
		label.text = _get_layer_label(i)
		label.size_flags_horizontal = 0
		vbox.add_child(label)
		
		var mute_button: CheckButton = CheckButton.new()
		mute_button.name = "MuteButton%d" % (i + 1)
		mute_button.text = ""
		mute_button.size_flags_horizontal = 0
		mute_button.toggled.connect(_on_dynamic_mute_toggled.bind(i))
		vbox.add_child(mute_button)
		
		mute_layers_container.add_child(layer_row)

## Removes all dynamically created layer boxes from the mute-layers container.
func _clear_mute_layers():
	for child in mute_layers_container.get_children():
		child.queue_free()

## Handles dynamic mute-checkbox changes for a specific layer.
func _on_dynamic_mute_toggled(toggled: bool, layer_index: int):
	if music_director:
		music_director.set_layer_mute(layer_index, toggled)

## Returns the display label for a given layer index.
func _get_layer_label(layer_index: int) -> String:
	return "Layer %d" % (layer_index + 1)

## Returns a color from the debugger palette for a given layer index.
func _get_layer_color(layer_index: int) -> Color:
	var palette: Array[Color] = [
		Color("a9445a"),
		Color("4b47b8"),
		Color("e8a29b"),
		Color("4f8f6a"),
		Color("b88a3b"),
		Color("7a5fb5")
	]

	return palette[layer_index % palette.size()]

## Updates the playhead and end-of-song display state each frame.
func _process(_delta):
	if clock_ref:
		if not clock_ref.is_running() and total_song_time > 0.0 and clock_ref.get_song_time() >= total_song_time - 0.05:
			beat_flash.modulate.a = 0.0
			play_button.text = "Replay"
			time_label.text = "Measure: -- Beat: --"
			next_cue_label.text = "Upcoming Cue: --"
		else:
			play_button.text = "Play"
	
	if clock_ref and clock_ref.is_running() and total_song_time > 0:
		var current_time: float = clock_ref.get_song_time()
		var ratio: float = clamp(current_time / total_song_time, 0.0, 1.0)
		playhead.anchor_left = ratio
		playhead.anchor_right = ratio

## Draws vertical cue markers on the timeline using the current song's cue data.
func _draw_cue_markers(offsets: PackedFloat32Array) -> void:
	var cues_by_measure: Dictionary = song_data.get_cues_by_measure()
	
	for measure_idx in cues_by_measure.keys():
		var cue_names: Array = cues_by_measure[measure_idx]
		
		if measure_idx < offsets.size():
			var cue_time: float = offsets[measure_idx]
			var ratio: float = cue_time / total_song_time
			
			var marker: ColorRect = ColorRect.new()
			marker.color = Color(0, 1, 0.5)
			marker.custom_minimum_size = Vector2(4, 10)
			timeline_track.add_child(marker)
			
			# Fixed marker height
			marker.anchor_left = ratio
			marker.anchor_right = ratio
			marker.anchor_top = 0.0
			marker.anchor_bottom = 0.0
			marker.offset_left = 0
			marker.offset_right = 4
			marker.offset_top = 0
			marker.offset_bottom = 24
			
			marker.tooltip_text = str(cue_names[0]) + " (Measure " + str(measure_idx + 1) + ")"

## Returns whether looping is currently enabled in the UI.
func is_loop_enabled() -> bool:
	return loop_enabled_check.button_pressed

## Returns the currently selected loop start measure.
func get_loop_start_measure() -> int:
	return int(loop_start_spinbox.value)

## Returns the currently selected loop end measure.
func get_loop_end_measure() -> int:
	return int(loop_end_spinbox.value)

## Returns whether repeated cue resolution should prefer previous occurrences.
func should_jump_back() -> bool:
	return jump_back_check.button_pressed

# Signals

## Emits a play request.
func _on_play_button_pressed() -> void:
	play_requested.emit()

## Emits a pause request.
func _on_pause_button_pressed() -> void:
	pause_requested.emit()

## Emits a restart request.
func _on_restart_button_pressed() -> void:
	restart_requested.emit()

## Emits the currently selected loop settings to be applied by the runtime.
func _on_apply_loop_button_pressed() -> void:
	var start_measure: int = int(loop_start_spinbox.value)
	var end_measure: int = int(loop_end_spinbox.value)

	if end_measure <= start_measure:
		end_measure = start_measure + 1
		loop_end_spinbox.value = end_measure

	loop_settings_requested.emit(loop_enabled_check.button_pressed, start_measure, end_measure)

## Immediately disables looping when the loop-enabled checkbox is unchecked.
func _on_loop_enabled_toggled(enabled: bool) -> void:
	if not enabled:
		var start_measure: int = int(loop_start_spinbox.value)
		var end_measure: int = int(loop_end_spinbox.value)
		loop_settings_requested.emit(false, start_measure, end_measure)

## Emits a queued jump request using the currently selected trigger and destination controls.
func _on_queue_jump_button_pressed() -> void:
	var trigger_type: String = trigger_type_select.get_item_text(trigger_type_select.selected)
	var destination_type: String = destination_type_select.get_item_text(destination_type_select.selected)

	var trigger_value: Variant
	if trigger_type == "Cue":
		var idx: int = max(trigger_cue_select.selected, 0)
		trigger_value = StringName(trigger_cue_select.get_item_text(idx))
	else:
		trigger_value = int(trigger_measure_spinbox.value)

	var destination_value: Variant
	if destination_type == "Cue":
		var idx: int = max(destination_cue_select.selected, 0)
		destination_value = StringName(destination_cue_select.get_item_text(idx))
	else:
		destination_value = int(destination_measure_spinbox.value)

	queued_jump_requested.emit(trigger_type, trigger_value, destination_type, destination_value)

## Emits an immediate jump request using the currently selected destination controls.
func _on_immediate_jump_button_pressed() -> void:
	var destination_type: String = immediate_destination_type_select.get_item_text(immediate_destination_type_select.selected)

	var destination_value: Variant
	if destination_type == "Cue":
		var idx: int = max(immediate_destination_cue_select.selected, 0)
		destination_value = StringName(immediate_destination_cue_select.get_item_text(idx))
	else:
		destination_value = int(immediate_destination_measure_spinbox.value)

	immediate_jump_requested.emit(destination_type, destination_value)

## Updates the measure/beat display and flashes the visual metronome on each beat event.
func _on_beat(beat_number: int) -> void:
	print("Beat: ", beat_number)
	time_label.text = "Measure %d | Beat: %d" % [current_measure, beat_number]
	
	var tween = create_tween()
	tween.tween_property(beat_flash, "modulate:a", 1.0, 0.0)
	tween.tween_property(beat_flash, "modulate:a", 0.0, 0.5)

## Updates current measure display and computes the next upcoming cue.
func _on_measure(measure_number: int) -> void:
	print(">> MEASURE: ", measure_number)
	current_measure = measure_number
	
	if song_data:
		var cues = song_data.get_cues_by_measure()
		var found_cue: bool = false
		
		# cues_by_measure is 0-based internally, while measure signal is 1-based
		for i in range(current_measure + 1, current_measure + 21):
			var cue_index: int = i - 1
			if cues.has(cue_index):
				var markers = cues[cue_index]
				next_cue_label.text = "Upcoming: '" + str(markers[0]) + "' at Measure " + str(i)
				found_cue = true
				break
			
		if not found_cue:
			next_cue_label.text = "Upcoming: None"

## Logs markers as they are passed by the clock.
func _on_marker(marker_name: String) -> void:
	print("** PASSED MARKER: ", marker_name)

## Emits a request to load the currently selected song preset.
func _on_load_song_button_pressed() -> void:
	if song_select.item_count <= 0:
		return
	
	var idx: int = song_select.selected
	if idx < 0:
		idx = 0
	
	var song_name: String = song_select.get_item_text(idx)
	song_load_requested.emit(song_name)

## Connects beat, measure, and marker signals from the active clock if they are not already connected.
func _connect_clock_signals() -> void:
	if clock_ref == null:
		return
	
	if not clock_ref.beat.is_connected(_on_beat):
		clock_ref.beat.connect(_on_beat)
	if not clock_ref.measure.is_connected(_on_measure):
		clock_ref.measure.connect(_on_measure)
	if not clock_ref.marker_passed.is_connected(_on_marker):
		clock_ref.marker_passed.connect(_on_marker)

## Disconnects beat, measure, and marker signals from the previously active clock.
func _disconnect_clock_signals() -> void:
	if clock_ref == null:
		return
	
	if clock_ref.beat.is_connected(_on_beat):
		clock_ref.beat.disconnect(_on_beat)
	if clock_ref.measure.is_connected(_on_measure):
		clock_ref.measure.disconnect(_on_measure)
	if clock_ref.marker_passed.is_connected(_on_marker):
		clock_ref.marker_passed.disconnect(_on_marker)

## Removes all cue markers from the timeline while preserving the playhead.
func _clear_timeline_markers() -> void:
	for child in timeline_track.get_children():
		if child != playhead:
			child.queue_free()

## Updates visibility of cue/measure controls based on the selected transition routing modes.
func _update_transition_control_visibility() -> void:
	var trigger_is_cue: bool = trigger_type_select.get_item_text(trigger_type_select.selected) == "Cue"
	trigger_cue_select.visible = trigger_is_cue
	trigger_measure_spinbox.visible = not trigger_is_cue

	var destination_is_cue: bool = destination_type_select.get_item_text(destination_type_select.selected) == "Cue"
	destination_cue_select.visible = destination_is_cue
	destination_measure_spinbox.visible = not destination_is_cue

	var immediate_is_cue: bool = immediate_destination_type_select.get_item_text(immediate_destination_type_select.selected) == "Cue"
	immediate_destination_cue_select.visible = immediate_is_cue
	immediate_destination_measure_spinbox.visible = not immediate_is_cue
	
	jump_back_check.visible = destination_is_cue or immediate_is_cue

## Refreshes transition-control visibility when a type selector changes.
func _on_transition_type_changed(_index: int) -> void:
	_update_transition_control_visibility()

## Emits a transition-style change when the Crossfade/Seamless selector changes.
func _on_transition_style_selected(index: int) -> void:
	var style_name := transition_style_select.get_item_text(index).to_lower()
	transition_style_changed.emit(style_name)
