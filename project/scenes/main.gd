extends Node

# The glue layer between Music Director / UI

@onready var music_director: MusicDirector = $MusicDirector
@onready var visual_debugger = $UI/VisualDebugger
@onready var transition_button = $UI/TransitionButton
@onready var immediate_button = $UI/ImmediateButton

func _ready():
	# - Load Data -
	# Load the Audio Stream (the .wav file)
	var audio_stream = preload("res://audio/test_music.wav")
	# Tell the Music Director to set everything up
	music_director.load_song("res://test_score.musicxml", audio_stream)
	
	# Tell the Debugger UI where to find the clock
	# Get the direct object reference from the director, and pass it to the UI
	var clock = music_director.get_audio_clock()
	visual_debugger.setup(clock)
	
	# Connect the UI buttons
	transition_button.pressed.connect(_on_transition_button_pressed)
	immediate_button.pressed.connect(_on_immediate_button_pressed)
	
	# Start the music! (Loop measures 1 through 6, exclusively)
	music_director.play_measures(1, 6, true)

# Input handling from UI
func _on_transition_button_pressed():
	# Tell the Music Director to wait for the 
	# "Transition_Point" marker and then jump to Measure 10
	music_director.request_jump_to_marker("Transition_Point", 10) # from, to

func _on_immediate_button_pressed():
	# Tell the Music Director to immediately jump, no matter the current context
	music_director.request_immediate_jump_to_measure(10)
