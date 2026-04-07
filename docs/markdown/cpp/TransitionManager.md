# TransitionManager

**Inherits:** `Node`

## Brief Description
Schedules musically timed transitions based on measures or cue markers.

## Description
`TransitionManager` listens to an `AudioClock` and waits for a specific musical condition before emitting `transition_triggered`. It supports queued transitions at measure boundaries, queued transitions at named cue markers, and immediate trigger requests that bypass waiting.

This separates the decision to transition from the actual playback logic that performs the jump or crossfade.

## Properties

### `clock_path: NodePath`
Path to the `AudioClock` node monitored by this manager.

## Methods

### `cancel_switch() -> void`
Cancels any currently queued transition request.

### `is_transition_queued() -> bool`
Returns `true` if a measure-based or marker-based transition request is currently pending.

### `queue_switch_at_marker(marker_name: StringName) -> void`
Queues a transition that will trigger when the connected `AudioClock` emits the specified cue marker.

### `queue_switch_at_measure(measure_number: int) -> void`
Queues a transition that will trigger when the connected `AudioClock` reaches the specified 1-based measure number.

### `trigger_transition_immediate() -> void`
Triggers `transition_triggered` immediately without waiting for a future measure or marker.

## Signals

### `transition_triggered(measure_number: int, marker_name: StringName)`
Emitted when the queued transition condition is met or when an immediate transition is requested.

For measure-based triggers, `measure_number` contains the triggering measure and `marker_name` is empty. For marker-based triggers, `marker_name` contains the cue name and `measure_number` is typically set to `-1` or another sentinel depending on the trigger path.