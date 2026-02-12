extends Node

@onready var audio_player = $AudioStreamPlayer
@onready var audio_clock = $AudioClock
@onready var parser = MusicXMLParser.new()

#func _ready():
	#var data := SongData.new()
	#data.measure_offsets = PackedFloat32Array([0.0, 1.0, 2.0, 3.0])
	#data.set_cue_point(&"intro", 0)
#
	#var clock := AudioClock.new()
	#clock.song_data = data
	#add_child(clock)
#
	#var tm := TransitionManager.new()
	#add_child(tm)
	#tm.clock_path = clock.get_path()
#
	#clock.bar.connect(func(b): print("bar:", b))
	#clock.marker_passed.connect(func(m): print("marker:", m))
	#tm.transition_triggered.connect(func(b, m): print("transition:", b, m))
#
	#tm.queue_switch_at_bar(2)
	#clock.start()

func _ready():
	# 1) Parse the Data
	var file_path = "res://test_score.musicxml"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var xml_content = file.get_as_text()
		var song_data = parser.parse_text(xml_content)
		
		# Save it to disk
		var error = ResourceSaver.save(song_data, "res://test_song_data.tres")
		if error == OK:
			print("Saved test_song_data.tres successfully!")
		else:
			print("Failed to save resource.")
		print("\n--------------------------\n")
		
		# 2) Feed Data to the Clock
		audio_clock.set_song_data(song_data)
		
		# 3) Tell Clock which audio player to watch
		# (This uses the NodePath to find the audio player)
		audio_clock.set_audio_player_path(audio_player.get_path())
		
		# 4) Connect Signals
		audio_clock.beat.connect(_on_beat)
		audio_clock.measure.connect(_on_measure)
		audio_clock.marker_passed.connect(_on_marker)
		
		# 5) Test looping (ex: loop through measures 2 - 4)
		#audio_clock.set_loop_bounds_measure(2, 4)
		
		 # 6) PLAY!
		audio_player.play()
		audio_clock.start()
	else:
		print("Error: Test MusicXML File not found!")

func _on_beat(beat_num):
	print("Beat: ", beat_num)

func _on_measure(measure_num):
	print(">> MEASURE: ", measure_num)

func _on_marker(marker_name):
	print("** PASSED MARKER: ", marker_name)
