# SongData

**Inherits:** `Resource`

## Brief Description
Stores parsed musical timing and structural data for a song.

## Description
A `Resource` that holds the parsed output of a MusicXML file. This includes tempo data, measure start times, beats-per-measure information, and cue markers.

`AudioClock`, `TransitionManager`, and higher-level playback scripts use this data to convert raw playback time into musical context.

## Properties

### `beats_per_measure: PackedInt32Array`
Stores the number of beats in each measure. This is primarily the time-signature numerator for each measure and is used by the clock to emit correct beat events.

### `bpm_map: PackedFloat32Array`
Stores the BPM value active at each measure.

### `cues_by_measure: Dictionary`
Lookup dictionary mapping internal 0-based measure indices to arrays of cue names found at those measure starts.

### `cues_by_name: Dictionary`
Lookup dictionary mapping cue names to arrays of internal 0-based measure indices where those cues occur.

### `measure_offsets: PackedFloat32Array`
Stores the exact start time in seconds for each measure, plus a final fencepost entry representing the end of the song.

## Methods

### `add_cue_point(name: StringName, measure_index: int) -> void`
Adds a cue marker at `measure_index`.

This updates both `cues_by_measure` and `cues_by_name` so the cue can be resolved efficiently in either direction.