extends Control

signal queued_jump_requested(marker_name: StringName, destination_measure: int)
signal immediate_jump_requested(destination_measure: int)
signal play_requested
signal pause_requested
signal loop_settings_requested(enabled: bool, start_measure: int, end_measure: int)

@export var clock_path: NodePath

@onready var time_label: Label = $MusicalDisplay/%TimeLabel
@onready var beat_flash: ColorRect = $MusicalDisplay/%BeatFlash
@onready var next_cue_label: Label = $MusicalDisplay/%NextCueLabel

@onready var timeline_track: ColorRect = $Timeline/%TimelineTrack
@onready var playhead: ColorRect = $Timeline/%PlayHead

@onready var cue_select: OptionButton = $TransitionOptions/%CueSelect
@onready var queued_destination_spinbox: SpinBox = $TransitionOptions/%QueuedDestinationSpinBox
@onready var queue_jump_button: Button = $TransitionOptions/%QueueJumpButton
@onready var immediate_destination_spinbox: SpinBox = $TransitionOptions/%ImmediateDestinationSpinBox
@onready var immediate_jump_button: Button = $TransitionOptions/%ImmediateJumpButton

@onready var play_button: Button = $PlayerOptions/%PlayButton
@onready var pause_button: Button = $PlayerOptions/%PauseButton
@onready var loop_enabled_check: CheckBox = $PlayerOptions/%LoopEnabledCheckBox
@onready var loop_start_spinbox: SpinBox = $PlayerOptions/%LoopStartSpinBox
@onready var loop_end_spinbox: SpinBox = $PlayerOptions/%LoopEndSpinBox
@onready var apply_loop_button: Button = $PlayerOptions/%ApplyLoopButton

var song_data: SongData
var clock_ref: AudioClock
var music_director: MusicDirector
var total_song_time: float = 0.0
var current_measure: int = 0

func _ready():
	beat_flash.modulate.a = 0.0

	music_director = get_parent().get_node("MusicDirector")
	$Timeline/%MuteButton1.toggled.connect(func(t): music_director.set_layer_mute(0, t))
	$Timeline/%MuteButton2.toggled.connect(func(t): music_director.set_layer_mute(1, t))
	$Timeline/%MuteButton3.toggled.connect(func(t): music_director.set_layer_mute(2, t))

	queue_jump_button.pressed.connect(_on_queue_jump_button_pressed)
	immediate_jump_button.pressed.connect(_on_immediate_jump_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	apply_loop_button.pressed.connect(_on_apply_loop_button_pressed)
	loop_enabled_check.toggled.connect(_on_loop_enabled_toggled)

func setup(clock: AudioClock):
	if clock:
		clock_ref = clock
		song_data = clock.get_song_data()

		clock.beat.connect(_on_beat)
		clock.measure.connect(_on_measure)
		clock.marker_passed.connect(_on_marker)

		var offsets: PackedFloat32Array = song_data.get_measure_offsets()
		if offsets.size() > 0:
			total_song_time = offsets[offsets.size() - 1]
			_draw_cue_markers(offsets)
			_setup_jump_controls(offsets)

		print("VisualDebugger: Successfully connected to AudioClock.")
	else:
		push_error("VisualDebugger: Provided AudioClock is null!")

func _setup_jump_controls(offsets: PackedFloat32Array):
	cue_select.clear()

	var cues_by_name: Dictionary = song_data.get_cues_by_name()
	var cue_names: Array = cues_by_name.keys()
	cue_names.sort()

	for cue_name in cue_names:
		cue_select.add_item(String(cue_name))

	var max_measure: int = max(1, offsets.size() - 1)
	queued_destination_spinbox.min_value = 1
	queued_destination_spinbox.max_value = max_measure
	queued_destination_spinbox.step = 1
	#queued_destination_spinbox.value = min(6, max_measure)

	immediate_destination_spinbox.min_value = 1
	immediate_destination_spinbox.max_value = max_measure
	immediate_destination_spinbox.step = 1
	#immediate_destination_spinbox.value = min(6, max_measure)
	
	loop_start_spinbox.min_value = 1
	loop_start_spinbox.max_value = max_measure
	loop_start_spinbox.step = 1
	loop_start_spinbox.value = 1

	loop_end_spinbox.min_value = 1
	loop_end_spinbox.max_value = max_measure
	loop_end_spinbox.step = 1
	loop_end_spinbox.value = min(6, max_measure)

func _process(_delta):
	if clock_ref and clock_ref.is_running() and total_song_time > 0:
		var current_time: float = clock_ref.get_song_time()
		var ratio: float = clamp(current_time / total_song_time, 0.0, 1.0)

		playhead.anchor_left = ratio
		playhead.anchor_right = ratio

func _draw_cue_markers(offsets: PackedFloat32Array):
	var cues_by_measure: Dictionary = song_data.get_cues_by_measure()

	for measure_idx in cues_by_measure.keys():
		var cue_names: Array = cues_by_measure[measure_idx]

		if measure_idx < offsets.size():
			var cue_time: float = offsets[measure_idx]
			var ratio: float = cue_time / total_song_time

			var marker: ColorRect = ColorRect.new()
			marker.color = Color(0, 1, 0.5)
			marker.custom_minimum_size = Vector2(4, 30)
			timeline_track.add_child(marker)

			marker.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			marker.anchor_left = ratio
			marker.anchor_right = ratio

			marker.tooltip_text = str(cue_names[0]) + " (Measure " + str(measure_idx + 1) + ")"

func is_loop_enabled() -> bool:
	return loop_enabled_check.button_pressed

func get_loop_start_measure() -> int:
	return int(loop_start_spinbox.value)

func get_loop_end_measure() -> int:
	return int(loop_end_spinbox.value)

# Signals
func _on_play_button_pressed():
	play_requested.emit()

func _on_pause_button_pressed():
	pause_requested.emit()

func _on_apply_loop_button_pressed():
	var start_measure: int = int(loop_start_spinbox.value)
	var end_measure: int = int(loop_end_spinbox.value)

	if end_measure <= start_measure:
		end_measure = start_measure + 1
		loop_end_spinbox.value = end_measure

	loop_settings_requested.emit(loop_enabled_check.button_pressed, start_measure, end_measure)

func _on_loop_enabled_toggled(enabled: bool):
	if not enabled:
		var start_measure: int = int(loop_start_spinbox.value)
		var end_measure: int = int(loop_end_spinbox.value)
		loop_settings_requested.emit(false, start_measure, end_measure)

func _on_queue_jump_button_pressed():
	if cue_select.item_count <= 0:
		return

	var selected_index: int = cue_select.selected
	if selected_index < 0:
		selected_index = 0

	var marker_name := StringName(cue_select.get_item_text(selected_index))
	var destination_measure: int = int(queued_destination_spinbox.value)
	queued_jump_requested.emit(marker_name, destination_measure)

func _on_immediate_jump_button_pressed():
	var destination_measure: int = int(immediate_destination_spinbox.value)
	immediate_jump_requested.emit(destination_measure)

func _on_beat(beat_number: int):
	print("Beat: ", beat_number)
	time_label.text = "Measure %d | Beat: %d" % [current_measure, beat_number]

	var tween = create_tween()
	tween.tween_property(beat_flash, "modulate:a", 1.0, 0.0)
	tween.tween_property(beat_flash, "modulate:a", 0.0, 0.5)

func _on_measure(measure_number: int):
	print(">> MEASURE: ", measure_number)
	current_measure = measure_number

	if song_data:
		var cues = song_data.get_cues_by_measure()
		var found_cue: bool = false

		# cues_by_measure is 0-based internally, while measure signal is 1-based
		for i in range(current_measure, current_measure + 20):
			var cue_index: int = i - 1
			if cues.has(cue_index):
				var markers = cues[cue_index]
				next_cue_label.text = "Upcoming: '" + str(markers[0]) + "' at Measure " + str(i)
				found_cue = true
				break

		if not found_cue:
			next_cue_label.text = "Upcoming: None"

func _on_marker(marker_name: String):
	print("** PASSED MARKER: ", marker_name)
