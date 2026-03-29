# The glue layer between Music Director / UI

extends Node

@onready var music_director: MusicDirector = $MusicDirector
@onready var visual_debugger = $VisualDebugger

func _ready():
	# Load data
	var audio_stems: Array[AudioStream] = [
		preload("res://audio/test_music/test_music_1.wav"),
		preload("res://audio/test_music/test_music_2.wav"),
		preload("res://audio/test_music/test_music_3.wav")
	]
	music_director.load_song("res://test_score.musicxml", audio_stems)
	
	# Pass a reference of the clock to the visual debugger
	var clock = music_director.get_audio_clock()
	visual_debugger.setup(clock)
	
	# Connect UI buttons
	visual_debugger.queued_jump_requested.connect(_on_queued_jump_requested)
	visual_debugger.immediate_jump_requested.connect(_on_immediate_jump_requested)
	visual_debugger.play_requested.connect(_on_play_requested)
	visual_debugger.pause_requested.connect(_on_pause_requested)
	visual_debugger.loop_settings_requested.connect(_on_loop_settings_requested)
	
	# Play!
	#music_director.play_measures(1, 6, true)

func _on_queued_jump_requested(marker_name: StringName, destination_measure: int):
	music_director.request_jump_to_marker(marker_name, destination_measure)

func _on_immediate_jump_requested(destination_measure: int):
	music_director.request_immediate_jump_to_measure(destination_measure)

func _on_play_requested():
	var loop_enabled: bool = visual_debugger.is_loop_enabled()
	var loop_start: int = visual_debugger.get_loop_start_measure()
	var loop_end: int = visual_debugger.get_loop_end_measure()
	
	music_director.play_from_ui(loop_enabled, loop_start, loop_end)

func _on_pause_requested():
	music_director.pause_music()

func _on_loop_settings_requested(enabled: bool, start_measure: int, end_measure: int):
	music_director.set_loop_enabled(enabled, start_measure, end_measure)
