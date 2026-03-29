class_name MusicDirector
extends Node

@onready var audio_clock: AudioClock = $AudioClock
@onready var transition_manager: TransitionManager = $TransitionManager

var song_data: SongData
var target_destination_measure: int = -1
var stem_streams: Array[AudioStream] = []

# Now each active player is one whole synchronized group, not one stem.
var active_audio_group_players: Array[AudioStreamPlayer] = []

# Keep track of each active synchronized stream so layer mute changes can be
# applied to currently playing and currently fading groups.
var active_sync_streams: Array[AudioStreamSynchronized] = []

# Store target per-layer volume so newly spawned groups inherit mute state.
var layer_volumes_db: Array[float] = []

@onready var has_started_playback: bool = false

func _ready():
	transition_manager.set_clock_path(audio_clock.get_path())
	transition_manager.transition_triggered.connect(_on_transition_triggered)
	audio_clock.loop_occurred.connect(_on_loop_occurred)


# --- THE PUBLIC API ---

func get_audio_clock() -> AudioClock:
	return audio_clock

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

func play_full_song():
	audio_clock.clear_loop()
	_spawn_stem_group(0.0, 0.0)
	audio_clock.start(0.0)

func play_from_ui(loop_enabled: bool, start_measure: int, end_measure: int):
	if audio_clock.is_running():
		return

	if not has_started_playback or active_audio_group_players.is_empty():
		if loop_enabled:
			play_measures(start_measure, end_measure, true)
		else:
			play_full_song()
		has_started_playback = true
	else:
		resume_music()

# Additional Controls (Pause/Resume/Stop/Loop)
func pause_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stream_paused = true
	audio_clock.stop()

func resume_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stream_paused = false
	audio_clock.resume()

func stop_music():
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.queue_free()

	active_audio_group_players.clear()
	active_sync_streams.clear()
	audio_clock.stop()
	has_started_playback = false

func set_loop_enabled(enabled: bool, start_measure: int = 1, end_measure: int = 2):
	if enabled:
		audio_clock.set_loop_bounds_measure(start_measure, end_measure)
	else:
		audio_clock.clear_loop()

# Transition Requests
func request_jump_to_measure(wait_for_measure: int, destination_measure: int):
	print("Director: Queued jump. Waiting for measure ", wait_for_measure, " to jump to ", destination_measure)
	target_destination_measure = destination_measure
	transition_manager.queue_switch_at_measure(wait_for_measure)

func request_jump_to_marker(wait_marker: StringName, destination_measure: int):
	print("Director: Queued jump. Waiting for marker '", wait_marker, "' to jump to ", destination_measure)
	target_destination_measure = destination_measure
	transition_manager.queue_switch_at_marker(wait_marker)

func request_immediate_jump_to_measure(destination_measure: int):
	print("Director: IMMEDIATE JUMP REQUESTED.")
	target_destination_measure = destination_measure
	transition_manager.trigger_transition_immediate()

# Muting Layers
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
func _on_loop_occurred(new_time: float) -> void:
	for audio_player in active_audio_group_players:
		if is_instance_valid(audio_player):
			audio_player.seek(new_time)

# Transitions and Crossfading
func _on_transition_triggered(measure_number: int, marker_name: StringName):
	if target_destination_measure <= 0:
		return

	call_deferred("_execute_transition", measure_number, marker_name)

func _execute_transition(measure_number: int, marker_name: StringName):
	print("MusicDirector: EXECUTE JUMP TO MEASURE ", target_destination_measure)

	var offsets: PackedFloat32Array = song_data.get_measure_offsets()
	var target_index: int = target_destination_measure - 1

	if target_index >= 0 and target_index < offsets.size():
		var target_time_seconds: float = offsets[target_index]
		
		#var end_measure: int = audio_clock.get_num_measures() + 1
		#audio_clock.set_loop_bounds_measure(target_destination_measure, end_measure)
		
		var fade_duration: float = 0.2
		if measure_number == -1 and marker_name == StringName():
			fade_duration = 0.0
		
		_spawn_stem_group(target_time_seconds, fade_duration)
		audio_clock.start(target_time_seconds)
		target_destination_measure = -1

func _spawn_stem_group(start_time: float, fade_duration: float):
	var sync_stream := _build_synchronized_stream()
	if sync_stream == null:
		push_error("MusicDirector: Failed to build synchronized stream.")
		return

	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = sync_stream

	# Player-level volume controls the crossfade between old and new groups.
	audio_player.volume_db = -80.0 if fade_duration > 0.0 else 0.0

	add_child(audio_player)

	# The clock now tracks one player for the whole synchronized group.
	audio_clock.set_audio_player_path(audio_player.get_path())

	audio_player.play(start_time)

	var new_audio_players: Array[AudioStreamPlayer] = [audio_player]
	var new_sync_streams: Array[AudioStreamSynchronized] = [sync_stream]

	_crossfade_groups(active_audio_group_players, new_audio_players, fade_duration)

	active_audio_group_players = new_audio_players
	active_sync_streams = new_sync_streams

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

func _crossfade_groups(old_audio_players: Array[AudioStreamPlayer], new_audio_players: Array[AudioStreamPlayer], duration: float):
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

	for new_audio_player in new_audio_players:
		if is_instance_valid(new_audio_player):
			tween.tween_property(new_audio_player, "volume_db", 0.0, duration)

# Muting Layers
func _set_layer_volume_for_active_streams(volume_db: float, index: int):
	for sync_stream in active_sync_streams:
		if sync_stream != null and index >= 0 and index < sync_stream.stream_count:
			sync_stream.set_sync_stream_volume(index, volume_db)
