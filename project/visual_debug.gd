# Visual Debugger
extends Control

@export var clock_path: NodePath

@onready var time_label: Label = $TimeLabel
@onready var beat_flash: ColorRect = $BeatFlash

var current_measure: int = 0

func _ready():
	# Initial state for the flash
	beat_flash.modulate.a = 0.0 # Make it invisible at the start
	print("In Visual Debug")
	var clock = get_node_or_null(clock_path)
	if clock:
		# Connect to the C++ signals
		clock.beat.connect(_on_beat)
		clock.measure.connect(_on_measure)
		clock.marker_passed.connect(_on_marker)
	else:
		print("Debugger Error: AudioClock node not found at path: ", clock_path)


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

func _on_marker(marker_name: String):
	print("** PASSED MARKER: ", marker_name)
