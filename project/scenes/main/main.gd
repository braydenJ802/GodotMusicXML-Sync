# The glue layer between Music Director / UI

extends Node
## Demo scene coordinator that connects the UI to the playback runtime.
##
## This script defines song presets, loads MusicXML + audio stem bundles, and
## routes [VisualDebugger] requests into [MusicDirector].

## Reference to the scene's central playback coordinator.
@onready var music_director: MusicDirector = $MusicDirector
## Reference to the in-engine debugger/control surface UI.
@onready var visual_debugger = $VisualDebugger


# Songs

## Dictionary of demo song presets.
##
## Each preset defines a MusicXML file, a list of synchronized audio stem paths,
## and a default transition style used when the preset is loaded.
var song_presets: Dictionary = {
	# Written by me
	"Test Score": {
		"xml": "res://xml/test_score.musicxml",
		"stems": [
			"res://audio/test_music/test_music_1.wav",
			"res://audio/test_music/test_music_2.wav",
			"res://audio/test_music/test_music_3.wav"
		],
		"default_transition_style": "crossfade"
	},
	# Redeemer of Israel
	"Hymn Demo": {
		"xml": "res://xml/example_hymn.musicxml",
		"stems": [
			"res://audio/hymns/example_hymn_soprano.wav",
			"res://audio/hymns/example_hymn_alto.wav",
			"res://audio/hymns/example_hymn_tenor.wav",
			"res://audio/hymns/example_hymn_bass.wav"
		],
		"default_transition_style": "seamless"
	}
}

## Initializes the demo scene, hooks up UI signals, and loads the default song preset.
func _ready():
	# Pass a reference of the clock to the visual debugger
	var clock = music_director.get_audio_clock()
	visual_debugger.setup(clock)
	
	# Connect UI buttons
	visual_debugger.queued_jump_requested.connect(_on_queued_jump_requested)
	visual_debugger.immediate_jump_requested.connect(_on_immediate_jump_requested)
	visual_debugger.play_requested.connect(_on_play_requested)
	visual_debugger.pause_requested.connect(_on_pause_requested)
	visual_debugger.restart_requested.connect(_on_restart_requested)
	visual_debugger.loop_settings_requested.connect(_on_loop_settings_requested)
	visual_debugger.song_load_requested.connect(_on_song_load_requested)
	visual_debugger.transition_style_changed.connect(_on_transition_style_changed)
	
	visual_debugger.set_song_options(song_presets.keys())
	# Load a default preset
	_load_song_preset("Test Score")
	
	# Play!
	#music_director.play_measures(1, 6, true)

## Loads a song preset by name, including MusicXML, stem audio, and default transition style.
func _load_song_preset(song_name: String) -> void:
	if not song_presets.has(song_name):
		push_error("Unknown song preset: " + song_name)
		return

	var preset: Dictionary = song_presets[song_name]
	var xml_path: String = preset["xml"]
	var stem_paths: Array = preset["stems"]
	var default_transition_style: String = preset["default_transition_style"]

	var audio_stems: Array[AudioStream] = []
	for stem_path in stem_paths:
		var stream: AudioStream = load(stem_path) as AudioStream
		if stream == null:
			push_error("Failed to load stem: " + str(stem_path))
			return
		audio_stems.append(stream)

	music_director.stop_music()
	music_director.load_song(xml_path, audio_stems)
	music_director.set_default_transition_style(default_transition_style)
	
	visual_debugger.refresh_for_new_song(music_director.get_audio_clock())
	visual_debugger.set_selected_song(song_name)
	visual_debugger.set_transition_style(default_transition_style)

## Handles a request from the UI to load a different song preset.
func _on_song_load_requested(song_name: String):
	_load_song_preset(song_name)

## Routes a queued jump request from the UI to the correct [MusicDirector] method.
##
## Trigger and destination may each be a cue or a measure. Cue destinations can
## optionally resolve backward depending on the debugger's Jump Back checkbox.
func _on_queued_jump_requested(trigger_type: String, trigger_value: Variant, destination_type: String, destination_value: Variant):
	var jump_back: bool = visual_debugger.should_jump_back()

	if trigger_type == "Measure" and destination_type == "Measure":
		music_director.request_jump_to_measure(int(trigger_value), int(destination_value))
	elif trigger_type == "Measure" and destination_type == "Cue":
		music_director.request_jump_to_cue_from_measure(int(trigger_value), StringName(destination_value), -1, jump_back)
	elif trigger_type == "Cue" and destination_type == "Measure":
		music_director.request_jump_to_marker(StringName(trigger_value), int(destination_value))
	elif trigger_type == "Cue" and destination_type == "Cue":
		music_director.request_jump_to_cue_from_marker(StringName(trigger_value), StringName(destination_value), -1, jump_back)

## Routes an immediate jump request from the UI to the correct [MusicDirector] method.
func _on_immediate_jump_requested(destination_type: String, destination_value: Variant):
	var jump_back: bool = visual_debugger.should_jump_back()

	if destination_type == "Measure":
		music_director.request_immediate_jump_to_measure(int(destination_value))
	else:
		music_director.request_immediate_jump_to_cue(StringName(destination_value), -1, jump_back)

## Handles the Play button using the loop settings currently displayed in the debugger.
func _on_play_requested():
	var loop_enabled: bool = visual_debugger.is_loop_enabled()
	var loop_start: int = visual_debugger.get_loop_start_measure()
	var loop_end: int = visual_debugger.get_loop_end_measure()
	
	music_director.play_from_ui(loop_enabled, loop_start, loop_end)

## Handles the Pause button.
func _on_pause_requested():
	music_director.pause_music()

## Handles the Restart button using the loop settings currently displayed in the debugger.
func _on_restart_requested():
	var loop_enabled: bool = visual_debugger.is_loop_enabled()
	var loop_start: int = visual_debugger.get_loop_start_measure()
	var loop_end: int = visual_debugger.get_loop_end_measure()

	music_director.restart_from_ui(loop_enabled, loop_start, loop_end)

## Applies loop settings requested by the debugger UI.
func _on_loop_settings_requested(enabled: bool, start_measure: int, end_measure: int):
	music_director.set_loop_enabled(enabled, start_measure, end_measure)

## Applies a new default transition style selected from the debugger UI.
func _on_transition_style_changed(style_name: String):
	music_director.set_default_transition_style(style_name)
