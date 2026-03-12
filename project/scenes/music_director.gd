class_name MusicDirector
extends Node

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_clock: AudioClock = $AudioClock
@onready var transition_manager: TransitionManager = $TransitionManager

var song_data: SongData
var target_destination_measure: int = -1

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
	audio_clock.set_audio_player_path(audio_player.get_path())
	
	# Set the Audio File
	audio_player.stream = audio_stream
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
	
	# Execute playback
	audio_player.play(start_time_seconds)
	audio_clock.start()

func play_full_song():
	# A function for convenience to just play the track from the very beginning natively
	audio_clock.clear_loop()
	audio_player.play(0.0)
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
		
		# Teleport the audio player
		audio_player.seek(target_time_seconds)
		
		# Update loop bounds (example: loop next 4 measures)
		var end_measure = offsets.size() # or audio_clock.get_num_measures() + 1
		audio_clock.set_loop_bounds_measure(target_destination_measure, end_measure)
		
		target_destination_measure = -1
