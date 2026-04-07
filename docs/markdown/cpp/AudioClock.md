# AudioClock

**Inherits:** `Node`

## Brief Description
Synchronizes musical game logic to live audio playback time.

## Description
`AudioClock` monitors an `AudioStreamPlayer` and translates playback time into musical position using data provided by a `SongData` resource. It tracks the current measure and beat, supports measure-based looping, and emits signals when beat, measure, marker, and loop events occur.

When an audio player is connected, the clock follows the player's playback position rather than relying on frame delta time.

## Properties

### `audio_player_path: NodePath`
Path to the `AudioStreamPlayer` node this clock should monitor for live playback position.

### `song_data: SongData`
The `SongData` resource containing the tempo map, measure offsets, beat counts, and cue markers for the current song.

## Methods

### `clear_loop() -> void`
Disables looping and clears any active loop bounds.

### `get_current_measure() -> int`
Returns the current measure number using 1-based numbering for public-facing use.

### `get_num_measures() -> float`
Returns the total number of measures defined by the loaded `SongData`.

### `get_song_time() -> float`
Returns the current playback position in seconds. When synchronized to an `AudioStreamPlayer`, this reflects the active audio playback position.

### `is_looping() -> bool`
Returns `true` if a loop section is currently active.

### `is_running() -> bool`
Returns `true` if the clock is currently advancing and emitting musical events.

### `resume() -> void`
Resumes the clock without resetting the current playback position, measure, or beat state.

### `set_loop_bounds_measure(start: int, end: int) -> void`
Sets the loop section using 1-based measure numbers. When playback reaches the end measure boundary, the clock emits `loop_occurred` with the loop restart time.

### `set_loop_bounds_time(start: float, end: float) -> void`
Sets the loop section directly using time values in seconds.

### `start(time_offset: float) -> void`
Starts the clock from `time_offset` seconds. This resets internal beat and measure tracking so playback can begin cleanly from a new position.

### `stop() -> void`
Stops the clock. No beat, measure, marker, or loop signals will be emitted while stopped.

## Signals

### `beat(beat_number: int)`
Emitted when the clock enters a new beat. Beat numbers are emitted using 1-based numbering.

### `loop_occurred(new_time: float)`
Emitted when playback reaches the loop end point and should return to `new_time`.

### `marker_passed(marker_name: StringName)`
Emitted when playback enters a measure that contains a parsed cue or rehearsal marker.

### `measure(measure_number: int)`
Emitted when the clock enters a new measure. Measure numbers are emitted using 1-based numbering.