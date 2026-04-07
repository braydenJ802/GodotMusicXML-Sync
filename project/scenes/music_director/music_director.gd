class_name MusicDirector
extends Node
## Coordinates score-aware playback, transitions, looping, and layered stem control.
##
## [MusicDirector] acts as the main runtime controller for the demo. It loads
## [SongData] from MusicXML, manages synchronized audio stems, routes queued and
## immediate transitions through [TransitionManager], and exposes transport and
## layer-muting controls for the UI.

## Reference to the runtime musical clock that tracks playback state.
@onready var audio_clock: AudioClock = $AudioClock
## Reference to the transition scheduler that waits for measure/cue triggers.
@onready var transition_manager: TransitionManager = $TransitionManager

## Parsed timing and cue data for the currently loaded song.
var song_data: SongData
## Pending destination measure for the next transition request, using 1-based numbering.
var target_destination_measure: int = -1
## Audio stems currently assigned to the loaded song.
var stem_streams: Array[AudioStream] = []

## Active synchronized playback groups currently alive in the scene.
##
## Under normal playback this usually contains one player. During a transition
## it may briefly contain both the fading-out and fading-in group.
var active_audio_group_players: Array[AudioStreamPlayer] = []

## Active synchronized stream resources corresponding to the current playback groups.
##
## These are tracked so per-layer mute changes can be applied to active groups.
var active_sync_streams: Array[AudioStreamSynchronized] = []

## Target per-layer volumes in decibels for newly spawned synchronized groups.
##
## This preserves mute state across transitions and restarts.
var layer_volumes_db: Array[float] = []

## Tracks whether playback has been started at least once in this session.
@onready var has_started_playback: bool = false

## Supported transition styles for musical jumps.
enum TransitionStyle {
	CROSSFADE,
	SEAMLESS
}

## Default transition style for new requests, typically set by the loaded song preset.
var default_transition_style: int = TransitionStyle.CROSSFADE
## Style that should be used for the next queued or immediate transition.
var pending_transition_style: int = TransitionStyle.CROSSFADE

## Initializes signal wiring between the director, clock, and transition manager.
func _ready():
	transition_manager.set_clock_path(audio_clock.get_path())
	transition_manager.transition_triggered.connect(_on_transition_triggered)
	audio_clock.loop_occurred.connect(_on_loop_occurred)

# --- THE PUBLIC API ---

## Returns the [AudioClock] used by this director.
func get_audio_clock() -> AudioClock:
	return audio_clock

## Returns the number of currently loaded audio layers/stems.
func get_layer_count() -> int:
	return stem_streams.size()

## Loads a MusicXML file and its corresponding stem audio into the runtime system.
##
## [param xml_path] is the resource path to the MusicXML file.
## [param audio_files] contains the stem streams that should be synchronized
## for playback.
func load_song(xml_path: String, audio_files: Array[AudioStream]):
	# Parse the XML
	var parser = MusicXMLParser.new()
	var file = FileAccess.open(xml_path, FileAccess.READ)
	song_data = parser.parse_text(file.get_as_text())

	# Feed Data to Clock
	audio_clock.set_song_data(song_data)

	# Set the Audio Files
	stem_streams = audio_files

	# Default all layers to audible
	layer_volumes_db.clear()
	for i in range(stem_streams.size()):
		layer_volumes_db.append(0.0)

	print("MusicDirector: Song (and stems) loaded successfully.")

## Starts playback from [param start_measure], optionally looping to [param end_measure].
##
## Measure numbers are 1-based. If [param should_loop] is [code]true[/code], the
## clock is configured to loop between the given measures.
func play_measures(start_measure: int, end_measure: int, should_loop: bool = false):
	var offsets: PackedFloat32Array = song_data.get_measure_offsets()
	var start_index: int = start_measure - 1

	if start_index < 0 or start_index >= offsets.size():
		push_error("MusicDirector: Invalid start measure (" + str(start_measure) + ").")
		return

	var start_time_seconds: float = offsets[start_index]

	if should_loop:
		audio_clock.set_loop_bounds_measure(start_measure, end_measure)
	else:
		audio_clock.clear_loop()

	_spawn_stem_group(start_time_seconds, 0.0)
	audio_clock.start(start_time_seconds)

## Starts playback from the beginning of the currently loaded song with looping disabled.
func play_full_song():
	audio_clock.clear_loop()
	_spawn_stem_group(0.0, 0.0)
	audio_clock.start(0.0)

## Handles the Play button behavior from the UI.
##
## If playback is already running, this does nothing. If playback is paused, it
## resumes. Otherwise it starts or restarts playback using the current loop settings.
func play_from_ui(loop_enabled: bool, start_measure: int, end_measure: int):
	if audio_clock.is_running():
		return
	
	# If paused, resume
	if _has_paused_playback():
		resume_music()
		return
	
	# If we get here, either nothing has started yet, or playback ended/stopped.
	stop_music()
	
	if loop_enabled:
		play_measures(start_measure, end_measure, true)
	else:
		play_full_song()
	has_started_playback = true

## Returns whether any active playback group is currently paused.
func _has_paused_playback() -> bool:
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player) and audio_player.stream_paused:
			return true
	return false

# Additional Controls (Pause/Resume/Stop/Loop)

## Pauses active audio playback and stops the clock from advancing.
func pause_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stream_paused = true
	audio_clock.stop()

## Resumes active audio playback and resumes the clock without resetting song position.
func resume_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stream_paused = false
	audio_clock.resume()

## Stops all active playback groups and resets transport state.
func stop_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.queue_free()

	active_audio_group_players.clear()
	active_sync_streams.clear()
	audio_clock.stop()
	has_started_playback = false

## Restarts playback from the beginning or from the active loop start based on UI settings.
func restart_from_ui(loop_enabled: bool, start_measure: int, end_measure: int):
	stop_music()

	if loop_enabled:
		play_measures(start_measure, end_measure, true)
	else:
		play_full_song()

	has_started_playback = true

## Enables or disables looping using 1-based measure boundaries.
func set_loop_enabled(enabled: bool, start_measure: int = 1, end_measure: int = 2):
	if enabled:
		audio_clock.set_loop_bounds_measure(start_measure, end_measure)
	else:
		audio_clock.clear_loop()

# Transition Requests

## Queues a transition that will trigger when playback reaches [param wait_for_measure].
##
## Both [param wait_for_measure] and [param destination_measure] use 1-based
## numbering. [param style] overrides the default transition style when not
## [code]-1[/code].
func request_jump_to_measure(wait_for_measure: int, destination_measure: int, style: int = -1):
	print("Director: Queued jump. Waiting for measure ", wait_for_measure, " to jump to ", destination_measure)
	target_destination_measure = destination_measure
	pending_transition_style = default_transition_style if style == -1 else style
	transition_manager.queue_switch_at_measure(wait_for_measure)

## Queues a transition that will trigger when playback reaches [param wait_marker].
##
## The destination is still expressed as a 1-based measure number.
func request_jump_to_marker(wait_marker: StringName, destination_measure: int, style: int = -1):
	print("Director: Queued jump. Waiting for marker '", wait_marker, "' to jump to ", destination_measure)
	target_destination_measure = destination_measure
	pending_transition_style = default_transition_style if style == -1 else style
	transition_manager.queue_switch_at_marker(wait_marker)

## Requests an immediate jump to [param destination_measure] without waiting for a trigger.
func request_immediate_jump_to_measure(destination_measure: int, style: int = -1):
	print("Director: IMMEDIATE JUMP REQUESTED.")
	target_destination_measure = destination_measure
	pending_transition_style = default_transition_style if style == -1 else style
	transition_manager.trigger_transition_immediate()

## Queues a measure-triggered jump whose destination is resolved from a cue name.
##
## If [param jump_back] is [code]true[/code], repeated cue names resolve to the
## nearest previous occurrence. Otherwise they resolve to the nearest forward occurrence.
func request_jump_to_cue_from_measure(wait_for_measure: int, destination_marker: StringName, style: int = -1, jump_back: bool = false):
	var destination_measure: int = get_best_measure_for_cue(destination_marker, not jump_back)
	if destination_measure <= 0:
		push_error("MusicDirector: Could not resolve destination cue: " + str(destination_marker))
		return
	request_jump_to_measure(wait_for_measure, destination_measure, style)

## Queues a cue-triggered jump whose destination is also resolved from a cue name.
func request_jump_to_cue_from_marker(wait_marker: StringName, destination_marker: StringName, style: int = -1, jump_back: bool = false):
	var destination_measure: int = get_best_measure_for_cue(destination_marker, not jump_back)
	if destination_measure <= 0:
		push_error("MusicDirector: Could not resolve destination cue: " + str(destination_marker))
		return
	request_jump_to_marker(wait_marker, destination_measure, style)

## Immediately jumps to a destination cue resolved relative to the current playback position.
func request_immediate_jump_to_cue(destination_marker: StringName, style: int = -1, jump_back: bool = false):
	var destination_measure: int = get_best_measure_for_cue(destination_marker, not jump_back)
	if destination_measure <= 0:
		push_error("MusicDirector: Could not resolve destination cue: " + str(destination_marker))
		return
	request_immediate_jump_to_measure(destination_measure, style)

## Sets the default transition style used by future requests when no explicit override is provided.
##
## Supported names are [code]"crossfade"[/code] and [code]"seamless"[/code].
func set_default_transition_style(style_name: String) -> void:
	match style_name.to_lower():
		"seamless":
			default_transition_style = TransitionStyle.SEAMLESS
		_:
			default_transition_style = TransitionStyle.CROSSFADE

## Resolves a cue name to the best matching destination measure relative to the current song position.
##
## By default this prefers the nearest forward occurrence. If [param prefer_forward]
## is [code]false[/code], it prefers the nearest previous occurrence.
func get_best_measure_for_cue(cue_name: StringName, prefer_forward: bool = true) -> int:
	if song_data == null:
		return -1

	var cues_by_name: Dictionary = song_data.get_cues_by_name()
	if not cues_by_name.has(cue_name):
		return -1

	var measures: Array = cues_by_name[cue_name]
	if measures.is_empty():
		return -1

	# current song position is 1-based from the clock
	var current_measure_1_based: int = max(1, int(audio_clock.get_current_measure()))
	var current_measure_0_based: int = current_measure_1_based - 1

	var sorted_measures: Array[int] = []
	for m in measures:
		sorted_measures.append(int(m))
	sorted_measures.sort()

	if prefer_forward:
		for m in sorted_measures:
			if m > current_measure_0_based:
				return m + 1

		# fallback if nothing forward exists
		return sorted_measures[0] + 1
	else:
		for i in range(sorted_measures.size() - 1, -1, -1):
			if sorted_measures[i] < current_measure_0_based:
				return sorted_measures[i] + 1

		# fallback if nothing backward exists
		return sorted_measures[sorted_measures.size() - 1] + 1

# Muting Layers

## Smoothly mutes or unmutes a specific synchronized stem layer.
##
## [param index] is zero-based relative to the loaded stem array.
func set_layer_mute(index: int, is_muted: bool):
	if index < 0 or index >= stem_streams.size():
		return

	while layer_volumes_db.size() < stem_streams.size():
		layer_volumes_db.append(0.0)

	var start_volume: float = layer_volumes_db[index]
	var target_volume: float = -80.0 if is_muted else 0.0
	layer_volumes_db[index] = target_volume

	var tween := create_tween()
	tween.tween_method(_set_layer_volume_for_active_streams.bind(index), start_volume, target_volume, 0.5)


# --- INTERNAL LOGIC ---

# Loops

## Seeks all active playback groups back to the loop restart time emitted by the clock.
func _on_loop_occurred(new_time: float) -> void:
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.seek(new_time)

# Transitions and Crossfading

## Receives a trigger from [TransitionManager] and defers the actual transition execution.
func _on_transition_triggered(measure_number: int, marker_name: StringName):
	if target_destination_measure <= 0:
		return

	call_deferred("_execute_transition", measure_number, marker_name)

## Executes a pending musical transition to the currently stored destination measure.
##
## The exact fade behavior depends on [member pending_transition_style] and whether
## the request was immediate or queued.
func _execute_transition(measure_number: int, marker_name: StringName) -> void:
	print("MusicDirector: EXECUTE JUMP TO MEASURE ", target_destination_measure)

	var offsets: PackedFloat32Array = song_data.get_measure_offsets()
	var target_index: int = target_destination_measure - 1

	if target_index >= 0 and target_index < offsets.size():
		var target_time_seconds: float = offsets[target_index]
		
		var is_immediate: bool = (measure_number == -1 and marker_name == StringName())
		
		var fade_out_duration: float = 0.0
		var fade_in_new_group: bool = false

		match pending_transition_style:
			TransitionStyle.CROSSFADE:
				fade_out_duration = 0.2 if is_immediate else 0.5
				fade_in_new_group = true

			TransitionStyle.SEAMLESS:
				# tiny old-player fade just to avoid click, but no audible suppression
				fade_out_duration = 0.01
				fade_in_new_group = false
				
		_spawn_stem_group(target_time_seconds, fade_out_duration, fade_in_new_group)
		audio_clock.start(target_time_seconds)
		target_destination_measure = -1

## Creates a new synchronized playback group starting at [param start_time] and hands it off to the crossfade system.
func _spawn_stem_group(start_time: float, fade_duration: float, fade_in_new_group: bool = true):
	var sync_stream := _build_synchronized_stream()
	if sync_stream == null:
		push_error("MusicDirector: Failed to build synchronized stream.")
		return
	
	var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_player.stream = sync_stream
	
	# Player-level volume controls the crossfade between old and new groups.
	audio_player.volume_db = -50.0 if (fade_duration > 0.0 and fade_in_new_group) else 0.0

	add_child(audio_player)

	# The clock now tracks one player for the whole synchronized group.
	audio_clock.set_audio_player_path(audio_player.get_path())

	audio_player.play(start_time)

	var new_audio_players: Array[AudioStreamPlayer] = [audio_player]
	var new_sync_streams: Array[AudioStreamSynchronized] = [sync_stream]

	_crossfade_groups(active_audio_group_players, new_audio_players, fade_duration, fade_in_new_group)

	active_audio_group_players = new_audio_players
	active_sync_streams = new_sync_streams

## Builds an [AudioStreamSynchronized] resource from the currently loaded stem streams.
##
## Current layer mute state is baked into the synchronized stream before playback begins.
func _build_synchronized_stream() -> AudioStreamSynchronized:
	if stem_streams.is_empty():
		return null

	var sync_stream := AudioStreamSynchronized.new()
	sync_stream.stream_count = stem_streams.size()

	for i in range(stem_streams.size()):
		sync_stream.set_sync_stream(i, stem_streams[i])

		var volume_db: float = 0.0
		if i < layer_volumes_db.size():
			volume_db = layer_volumes_db[i]

		sync_stream.set_sync_stream_volume(i, volume_db)

	return sync_stream

## Crossfades or hands off from old playback groups to new playback groups.
##
## If [param duration] is zero or less, old groups are cut immediately and new groups
## are brought in at full volume. Otherwise old groups fade out, and new groups either
## fade in or enter at full volume depending on [param fade_in_new_group].
func _crossfade_groups(old_audio_players: Array[AudioStreamPlayer], new_audio_players: Array[AudioStreamPlayer], \
duration: float, fade_in_new_group: bool = true) -> void:
	if duration <= 0.0:
		for old_audio_player in old_audio_players:
			if is_instance_valid(old_audio_player):
				old_audio_player.stop()
				old_audio_player.queue_free()

		for new_audio_player in new_audio_players:
			if is_instance_valid(new_audio_player):
				new_audio_player.volume_db = 0.0
		return

	var tween = create_tween().set_parallel(true)

	for old_audio_player in old_audio_players:
		if is_instance_valid(old_audio_player):
			tween.tween_property(old_audio_player, "volume_db", -80.0, duration)
			tween.chain().tween_callback(old_audio_player.queue_free)

	if fade_in_new_group:
		for new_audio_player in new_audio_players:
			if is_instance_valid(new_audio_player):
				tween.tween_property(new_audio_player, "volume_db", 0.0, duration)
	else:
		for new_audio_player in new_audio_players:
			if is_instance_valid(new_audio_player):
				new_audio_player.volume_db = 0.0

# Muting Layers

## Applies an interpolated layer volume to all currently tracked synchronized streams.
func _set_layer_volume_for_active_streams(volume_db: float, index: int):
	for sync_stream in active_sync_streams:
		if sync_stream != null and index >= 0 and index < sync_stream.stream_count:
			sync_stream.set_sync_stream_volume(index, volume_db)
