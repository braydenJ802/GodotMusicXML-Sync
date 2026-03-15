# Visual Debugger
extends Control

@export var clock_path: NodePath

@onready var time_label: Label = $TimeLabel
@onready var beat_flash: ColorRect = $BeatFlash

@onready var next_cue_label: Label = $NextCueLabel
var song_data: SongData

var current_measure: int = 0

func _ready():
	# Initial state for the flash
	beat_flash.modulate.a = 0.0 # Make it invisible at the start

func setup(clock: AudioClock):
	if clock:
		song_data = clock.get_song_data()
		
		# Connect to the C++ signals
		clock.beat.connect(_on_beat)
		clock.measure.connect(_on_measure)
		clock.marker_passed.connect(_on_marker)
		print("VisualDebugger: Successfully connected to AudioClock.")
	else:
		push_error("VisualDebugger: Provided AudioClock is null!")

func _on_beat(beat_number: int):
	print("Beat: ", beat_number + 1)
	# Update the label text
	time_label.text = "Measure %d | Beat: %d" % [current_measure + 1, beat_number + 1]
	
	# Create a flash animation using a Tween
	var tween = create_tween()
	# Make it start out opaque white
	tween.tween_property(beat_flash, "modulate:a", 1.0, 0.0)
	# Fade to transparent over 0.5 seconds
	tween.tween_property(beat_flash, "modulate:a", 0.0, 0.5)

func _on_measure(measure_number: int):
	print(">> MEASURE: ", measure_number + 1)
	# Just store the number (update for time label only)
	current_measure = measure_number
	
	# Look ahead for the next cue (up to 20 measures)
	if song_data:
		var cues = song_data.get_cues_by_measure()
		var found_cue: bool = false
		
		for i in range(current_measure + 1, current_measure + 20):
			if cues.has(i):
				var markers = cues[i]
				next_cue_label.text ="Upcoming: '" + str(markers[0]) + "' at Measure " + str(i)
				found_cue = true
				break
		
		if not found_cue:
			next_cue_label.text = "Upcoming: None" 

func _on_marker(marker_name: String):
	print("** PASSED MARKER: ", marker_name)
