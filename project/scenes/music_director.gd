class_name MusicDirector
extends Node

@onready var audio_clock: AudioClock = $AudioClock
@onready var transition_manager: TransitionManager = $TransitionManager

var song_data: SongData
var target_destination_measure: int = -1
var current_audio_stream: AudioStream

# We keep track of the currently playing node so we can fade it out later
var active_audio_player: AudioStreamPlayer = null

func _ready():
	transition_manager.set_clock_path(audio_clock.get_path())
	transition_manager.transition_triggered.connect(_on_transition_triggered)

# --- THE PUBLIC API ---

func get_audio_clock() -> AudioClock:
	return audio_clock

func load_song(xml_path: String, audio_stream: AudioStream):
	# Parse the XML
	var parser = MusicXMLParser.new()
	var file = FileAccess.open(xml_path, FileAccess.READ)
	song_data = parser.parse_text(file.get_as_text())
	
	# Feed Data to Clock
	audio_clock.set_song_data(song_data)
	
	# Set the Audio File
	current_audio_stream = audio_stream
	print("MusicDirector: Song loaded successfully.")

func play_measures(start_measure: int, end_measure: int, should_loop: bool = false):
	# Grab the array of timestamps from SongData
	var offsets = song_data.get_measure_offsets()
	
	# Convert musical measure (1-based) to array index (0-based)
	var start_index = start_measure - 1
	
	# Safety check to prevent out-of-bounds crashes
	if start_index < 0 or start_index >= offsets.size():
		push_error("MusicDirector: Invalid start measure (" + str(start_measure) + ").")
		return
		
	var start_time_seconds = offsets[start_index]
	
	# Handle the loop state
	if should_loop:
		# Tell the auido clock to trap the playback between these two measures
		audio_clock.set_loop_bounds_measure(start_measure, end_measure)
	else:
		# Clear any old loops so the song just plays straight through
		audio_clock.clear_loop()
	
	# Spawn a new audio player dynamically
	_spawn_new_audio_player(start_time_seconds, 0.0) # 0.0 fade means instant
	audio_clock.start()

func play_full_song():
	# A function for convenience to just play the track from the very beginning natively
	audio_clock.clear_loop()
	#audio_player.play(0.0)
	audio_clock.start()

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

# --- INTERNAL LOGIC ---

func _on_transition_triggered(measure_number: int, marker_name: StringName):
	if target_destination_measure <= 0:
		return 
		
	print("MusicDirector: EXECUTE JUMP TO MEASURE ", target_destination_measure)
	
	var offsets = song_data.get_measure_offsets()
	var target_index = target_destination_measure - 1
	
	if target_index >= 0 and target_index < offsets.size():
		var target_time_seconds = offsets[target_index]
		
		# Update loop bounds (example: loop next 4 measures)
		var end_measure = offsets.size() # or audio_clock.get_num_measures() + 1
		audio_clock.set_loop_bounds_measure(target_destination_measure, end_measure)
		
		# Spawn the new audio player and crossfade!
		_spawn_new_audio_player(target_time_seconds, 1.5) # 1.5 second crossfade
		
		target_destination_measure = -1

func _spawn_new_audio_player(start_time: float, fade_duration: float):
	# Create a brand new AudioStreamPlayer
	var new_audio_player: AudioStreamPlayer = AudioStreamPlayer.new()
	new_audio_player.stream = current_audio_stream
	add_child(new_audio_player) # Add it to the scene tree
	
	# Tell the audio clock to watch this new audio player
	audio_clock.set_audio_player_path(new_audio_player.get_path())
	# Crossfade (and set the new player to be active)
	active_audio_player = _crossfade_between_streams(new_audio_player, start_time, fade_duration)

func _crossfade_between_streams(audio_player: AudioStreamPlayer, start_time: float, fade_duration: float):
	if fade_duration > 0.0:
		audio_player.volume_db = -80.0
		audio_player.play(start_time)
		
		var tween = create_tween().set_parallel(true)
		# Fade new audio player IN
		tween.tween_property(audio_player, "volume_db", 0.0, fade_duration)
		
		# Fade old audio player OUT, then delete it to free memory
		if active_audio_player != null:
			tween.tween_property(active_audio_player, "volume_db", -80.0, fade_duration)
			tween.chain().tween_callback(active_audio_player.queue_free)
	else:
		# INSTANT PLAY
		audio_player.volume_db = 0.0
		audio_player.play(start_time)
		if active_audio_player != null:
			active_audio_player.queue_free()
	
	return audio_player
