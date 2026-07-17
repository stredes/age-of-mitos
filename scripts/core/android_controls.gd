## Coordination layer for touch/gesture input on mobile platforms.
##
## Detects platform, routes gestures between InputManager and CameraController,
## and prevents conflicting touch handling (e.g. box-select + camera pan on same finger).
## Add as a child of GameWorld before InputManager and CameraController in tree order.
extends Node

# =============================================================================
# Platform Detection
# =============================================================================

## Whether the current platform is mobile/touch-based.
var is_mobile: bool = false

## Whether the device has a touchscreen.
var has_touch: bool = false

# =============================================================================
# Gesture State
# =============================================================================

enum Gesture { NONE, TAPPING, SELECTING, BOX_SELECTING, PANNING, PINCHING, LONG_PRESSING }

## Current active gesture.
var active_gesture: Gesture = Gesture.NONE

## Number of fingers currently touching the screen.
var finger_count: int = 0

## Screen position where the primary gesture started.
var gesture_start_screen: Vector2 = Vector2.ZERO

## Time when the primary gesture started (seconds).
var gesture_start_time: float = 0.0

## Whether the primary finger has moved beyond tap threshold.
var has_dragged: bool = false

## Tap threshold in pixels — below this distance a press counts as tap.
var tap_threshold: float = 10.0

## Long press duration in seconds.
var long_press_duration: float = 0.4

# =============================================================================
# Touch Tracking
# =============================================================================

## Active touches: index -> screen position.
var _active_touches: Dictionary = {}

## Timestamps when each finger touched down: index -> time.
var _touch_start_times: Dictionary = {}

## Timestamp of last tap for double-tap detection.
var _last_tap_time: float = 0.0

## Screen position of last tap.
var _last_tap_position: Vector2 = Vector2.ZERO

## Double-tap time window.
var double_tap_window: float = 0.3

## Double-tap max distance.
var double_tap_tolerance: float = 40.0

# =============================================================================
# Long Press Timer
# =============================================================================

var _long_press_timer: float = 0.0
var _long_press_active: bool = false

# =============================================================================
# Touch Indicator Reference
# =============================================================================

var touch_indicator: Node = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	has_touch = DisplayServer.is_touchscreen_available() or is_mobile

	call_deferred("_find_touch_indicator")


func _process(delta: float) -> void:
	if active_gesture == Gesture.TAPPING or active_gesture == Gesture.LONG_PRESSING:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - gesture_start_time
		if not has_dragged and elapsed >= long_press_duration and not _long_press_active:
			_long_press_active = true
			active_gesture = Gesture.LONG_PRESSING


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


# =============================================================================
# Touch Handling
# =============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	var idx: int = event.index

	if event.pressed:
		_active_touches[idx] = event.position
		_touch_start_times[idx] = Time.get_ticks_msec() / 1000.0
		finger_count = _active_touches.size()

		if finger_count == 1:
			# First finger down — default to TAPPING until drag or long press.
			active_gesture = Gesture.TAPPING
			gesture_start_screen = event.position
			gesture_start_time = _touch_start_times[idx]
			has_dragged = false
			_long_press_active = false
			_show_tap_indicator(event.position)
		elif finger_count == 2:
			# Second finger — switch to PINCHING, cancel any selection gesture.
			active_gesture = Gesture.PINCHING
			_long_press_active = false
	else:
		_active_touches.erase(idx)
		_touch_start_times.erase(idx)
		finger_count = _active_touches.size()

		if finger_count == 0:
			# All fingers lifted.
			if active_gesture == Gesture.TAPPING:
				_handle_tap(event.position)
			elif active_gesture == Gesture.LONG_PRESSING:
				_handle_long_press_release(event.position)
			active_gesture = Gesture.NONE
			_long_press_active = false
			has_dragged = false
		elif finger_count == 1:
			# Went from 2 to 1 finger — resume single-finger state.
			_long_press_active = false
			if has_dragged:
				active_gesture = Gesture.BOX_SELECTING
			else:
				active_gesture = Gesture.TAPPING
				var remaining_idx: int = _active_touches.keys()[0]
				gesture_start_screen = _active_touches[remaining_idx]
				gesture_start_time = _touch_start_times.get(remaining_idx, 0.0)
				has_dragged = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	_active_touches[event.index] = event.position

	if finger_count < 1:
		return

	var dist: float = event.position.distance_to(gesture_start_screen)

	if active_gesture == Gesture.TAPPING:
		if dist > tap_threshold:
			has_dragged = true
			active_gesture = Gesture.BOX_SELECTING
	elif active_gesture == Gesture.PINCHING:
		# CameraController handles pinch internally.
		pass
	# BOX_SELECTING stays as-is — InputManager handles the selection box drawing.


# =============================================================================
# Gesture Queries (called by InputManager and CameraController)
# =============================================================================

## Returns true if the current gesture is a selection gesture (tap or box-select).
func is_selection_gesture() -> bool:
	return active_gesture in [Gesture.TAPPING, Gesture.BOX_SELECTING, Gesture.LONG_PRESSING]


## Returns true if the current gesture is a camera gesture (pinch or multi-finger pan).
func is_camera_gesture() -> bool:
	return active_gesture == Gesture.PINCHING


## Returns true if box selection is currently active.
func is_box_selecting() -> bool:
	return active_gesture == Gesture.BOX_SELECTING


## Returns true if a long press is being held.
func is_long_pressing() -> bool:
	return active_gesture == Gesture.LONG_PRESSING


## Returns true if any touch gesture is active.
func is_any_touch_active() -> bool:
	return finger_count > 0


## Returns the current gesture state.
func get_gesture() -> Gesture:
	return active_gesture


## Returns the number of active fingers.
func get_finger_count() -> int:
	return finger_count


# =============================================================================
# Tap Handling
# =============================================================================

func _handle_tap(tap_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var time_since_last: float = now - _last_tap_time
	var dist_from_last: float = tap_pos.distance_to(_last_tap_position)

	if time_since_last <= double_tap_window and dist_from_last <= double_tap_tolerance:
		# Double-tap → let CameraController center on position.
		# CameraController already handles this via _handle_tap.
		pass

	_last_tap_time = now
	_last_tap_position = tap_pos


func _handle_long_press_release(_pos: Vector2) -> void:
	pass


# =============================================================================
# Visual Feedback
# =============================================================================

func _show_tap_indicator(pos: Vector2) -> void:
	if touch_indicator != null and touch_indicator.has_method("show_tap"):
		touch_indicator.show_tap(pos)


# =============================================================================
# Helpers
# =============================================================================

func _find_touch_indicator() -> void:
	touch_indicator = get_node_or_null("/root/GameWorld/TouchLayer/TouchIndicator")
	if touch_indicator == null:
		touch_indicator = get_node_or_null("/root/GameWorld/UILayer/TouchIndicator")


## Force reset gesture state (call on menu open, build mode enter, etc.).
func reset_gesture() -> void:
	active_gesture = Gesture.NONE
	has_dragged = false
	_long_press_active = false
