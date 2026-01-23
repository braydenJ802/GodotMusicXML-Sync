@tool
extends Node

func _ready():
	var data := SongData.new()
	data.measure_offsets = PackedFloat32Array([0.0, 1.0, 2.0, 3.0])
	data.set_cue_point(&"intro", 0)

	var clock := AudioClock.new()
	clock.song_data = data
	add_child(clock)

	var tm := TransitionManager.new()
	add_child(tm)
	tm.clock_path = clock.get_path()

	clock.bar.connect(func(b): print("bar:", b))
	clock.marker_passed.connect(func(m): print("marker:", m))
	tm.transition_triggered.connect(func(b, m): print("transition:", b, m))

	tm.queue_switch_at_bar(2)
	clock.start()
