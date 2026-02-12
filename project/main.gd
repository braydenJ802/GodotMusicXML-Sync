@tool
extends Node

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
	# Load the file text
	var file_path = "res://test_score.musicxml"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var text_content = file.get_as_text()
		
		# Create the C++ Parser
		var parser = MusicXMLParser.new()
		
		#  Run it!
		var song_data = parser.parse_text(text_content)
		
		# Save it to disk
		var error = ResourceSaver.save(song_data, "res://test_song_data.tres")
		if error == OK:
			print("Saved test_song_data.tres successfully!")
		else:
			print("Failed to save resource.")
	else:
		print("Error: Test MusicXML File not found!")
