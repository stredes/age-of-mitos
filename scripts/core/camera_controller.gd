class_name CameraController
extends Camera2D

# =============================================================================
# Signals
# =============================================================================

signal camera_moved(position: Vector2)
signal camera_zoomed(zoom_level: float)

# =============================================================================
# Configuration
# =============================================================================

@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.5
@export var zoom_speed: float = 8.0
@export var zoom_lerp_speed: float = 12.0

@export var inertia_friction: float = 10.0
@export var pan_speed: float = 500.0
@export var keyboard_pan_speed: float = 800.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 20.0
@export var touch_edge_scroll_margin: float = 40.0

@export var map_size: Vector2 = Vector2(4096, 4096)

@export var follow_enabled: bool = false
@export var follow_target: Node2D = null
@export var follow_smoothing: float = 8.0
@export var follow_deadzone: float = 50.0

@export var double_tap_window: float = 0.3
@export var double_tap_tolerance: float = 30.0
@export var two_finger_pan_smoothing: float = 15.0
@export var pinch_zoom_smoothing: float = 10.0

@export var shake_enabled: bool = true
@export var shake_strength: float = 8.0
@export var shake_duration: float = 0.3
@export var shake_falloff: float = 0.5

# =============================================================================
# Internal State
# =============================================================================

var _velocity: Vector2 = Vector2.ZERO
var _target_zoom: float = 1.0
var _current_zoom: float = 1.0

var _active_touches: Dictionary = {}
var _is_panning: bool = false
var _is_pinch_zooming: bool = false
var _two_finger_pan_active: bool = false
var _pan_start_screen: Vector2 = Vector2.ZERO
var _pan_start_world: Vector2 = Vector2.ZERO

var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pinch_midpoint_screen: Vector2 = Vector2.ZERO
var _pinch_midpoint_world_before: Vector2 = Vector2.ZERO

var _last_tap_time: float = 0.0
var _last_tap_screen: Vector2 = Vector2.ZERO

var _shake_timer: float = 0.0
var _shake_current_strength: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

var _is_android: bool = OS.get_name() == "Android"
var _ui_rect: Rect2 = Rect2()

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_target_zoom = zoom.x
	_current_zoom = zoom.x
	zoom = Vector2.ONE * _target_zoom
	position = map_size * 0.5
	make_current()

	_get_ui_rect()


func _process(delta: float) -> void:
	_process_zoom(delta)
	_process_inertia(delta)
	_process_follow(delta)
	_process_shake(delta)
	_process_keyboard_and_edge_scroll(delta)
	_clamp_to_map_bounds()


func _unhandled_input(event: InputEvent) -> void:
	if _is_ui_interaction(event):
		return

	if _is_android:
		if event is InputEventScreenTouch:
			_handle_touch(event)
		elif event is InputEventScreenDrag:
			_handle_drag(event)
	else:
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
		elif event is InputEventMouseMotion:
			_handle_mouse_motion(event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = false


# =============================================================================
# UI Interaction Detection
# =============================================================================

func _is_ui_interaction(event: InputEvent) -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false

	if viewport.gui_get_focus_owner() != null:
		return true

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var screen_pos = event.position if event is InputEventScreenTouch else event.position
		if _ui_rect.has_point(screen_pos):
			return true

	return false


func _get_ui_rect() -> void:
	var viewport = get_viewport()
	if viewport == null:
		return

	var canvas_layers = viewport.get_canvas_layers()
	for layer in canvas_layers:
		if layer.name.begins_with("UI") or layer.name.begins_with("HUD") or layer.name == "CanvasLayer":
			var children = layer.get_children()
			for child in children:
				if child is Control:
					_ui_rect = _ui_rect.merge(child.get_rect())
					break


# =============================================================================
# Android Touch Handling
# =============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	var idx = event.index

	if event.pressed:
		_active_touches[idx] = event.position

		if _active_touches.size() == 1:
			_is_panning = true
			_velocity = Vector2.ZERO
			_pan_start_screen = event.position
			_pan_start_world = _screen_to_world(event.position)
		elif _active_touches.size() == 2:
			_is_panning = false
			_begin_two_finger_pan()
			_begin_pinch_zoom()
	else:
		_active_touches.erase(idx)

		if _active_touches.size() == 0:
			if _is_pinch_zooming:
				_end_pinch_zoom()
			elif _is_panning:
				var drag_dist = event.position.distance_to(_pan_start_screen)
				if drag_dist < double_tap_tolerance:
					_handle_tap(event.position)
			_is_panning = false
			_two_finger_pan_active = false
		elif _active_touches.size() == 1 and _is_pinch_zooming:
			_end_pinch_zoom()
			_begin_two_finger_pan()


func _handle_drag(event: InputEventScreenDrag) -> void:
	_active_touches[event.index] = event.position

	if _is_pinch_zooming and _active_touches.size() >= 2:
		_update_pinch_zoom()
		return

	if _active_touches.size() == 2:
		_update_two_finger_pan()
		return

	if _active_touches.size() == 1 and _is_panning:
		var delta_screen = event.relative
		var delta_world = delta_screen / _current_zoom
		position -= delta_world
		_velocity = -delta_world * 60.0
		_clamp_to_map_bounds()
		camera_moved.emit(position)


# =============================================================================
# Tap Handling
# =============================================================================

func _handle_tap(screen_pos: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var time_since_last = now - _last_tap_time
	var dist_from_last = screen_pos.distance_to(_last_tap_screen)

	if time_since_last <= double_tap_window and dist_from_last <= double_tap_tolerance:
		var world_pos = _screen_to_world(screen_pos)
		_center_on_smooth(world_pos)
		_last_tap_time = 0
		_last_tap_screen = Vector2.ZERO
	else:
		_last_tap_time = now
		_last_tap_screen = screen_pos


# =============================================================================
# Two-Finger Pan
# =============================================================================

func _begin_two_finger_pan() -> void:
	_two_finger_pan_active = true
	var positions = _active_touches.values()
	_pan_start_screen = (positions[0] + positions[1]) * 0.5


func _update_two_finger_pan() -> void:
	if _active_touches.size() < 2:
		return

	var positions = _active_touches.values()
	var current_mid = (positions[0] + positions[1]) * 0.5
	var delta_screen = current_mid - _pan_start_screen

	if delta_screen.length() > 1.0:
		var delta_world = delta_screen / _current_zoom
		position -= delta_world * two_finger_pan_smoothing * (1.0 / 60.0)
		_velocity = -delta_world * two_finger_pan_smoothing
		_pan_start_screen = current_mid
		_clamp_to_map_bounds()
		camera_moved.emit(position)


func _end_two_finger_pan() -> void:
	_two_finger_pan_active = false


# =============================================================================
# Pinch Zoom
# =============================================================================

func _begin_pinch_zoom() -> void:
	_is_pinch_zooming = true
	_two_finger_pan_active = false

	var positions = _active_touches.values()
	var pos_a = positions[0]
	var pos_b = positions[1]

	_pinch_start_distance = pos_a.distance_to(pos_b)
	_pinch_start_zoom = _target_zoom
	_pinch_midpoint_screen = (pos_a + pos_b) * 0.5
	_pinch_midpoint_world_before = _screen_to_world(_pinch_midpoint_screen)


func _update_pinch_zoom() -> void:
	if _active_touches.size() < 2:
		return

	var positions = _active_touches.values()
	var pos_a = positions[0]
	var pos_b = positions[1]

	var current_distance = pos_a.distance_to(pos_b)

	if _pinch_start_distance <= 0.0:
		return

	var ratio = current_distance / _pinch_start_distance
	var new_zoom = _pinch_start_zoom * ratio
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)

	var midpoint_world_after = _screen_to_world(_pinch_midpoint_screen)
	position += _pinch_midpoint_world_before - midpoint_world_after
	_clamp_to_map_bounds()


func _end_pinch_zoom() -> void:
	_is_pinch_zooming = false


# =============================================================================
# Zoom Processing
# =============================================================================

func _process_zoom(delta: float) -> void:
	if not is_equal_approx(_current_zoom, _target_zoom):
		_current_zoom = lerpf(_current_zoom, _target_zoom, zoom_lerp_speed * delta)
		zoom = Vector2.ONE * _current_zoom
		camera_zoomed.emit(_current_zoom)


# =============================================================================
# Inertia & Follow
# =============================================================================

func _process_inertia(delta: float) -> void:
	if _is_panning or _two_finger_pan_active or _is_pinch_zooming:
		return

	if _velocity.length_squared() > 1.0:
		var decay = exp(-inertia_friction * delta)
		_velocity *= decay
		position -= _velocity * delta
		_clamp_to_map_bounds()
		camera_moved.emit(position)


func _process_follow(delta: float) -> void:
	if not follow_enabled or follow_target == null or not is_instance_valid(follow_target):
		return

	var target_pos = follow_target.global_position
	var distance = position.distance_to(target_pos)

	if distance > follow_deadzone:
		position = position.lerp(target_pos, follow_smoothing * delta)
		_clamp_to_map_bounds()
		camera_moved.emit(position)


# =============================================================================
# Keyboard & Edge Scroll
# =============================================================================

func _process_keyboard_and_edge_scroll(delta: float) -> void:
	if _is_panning or _two_finger_pan_active or _is_pinch_zooming:
		return

	var direction = Vector2.ZERO
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position() if viewport else Vector2.ZERO
	var viewport_rect = get_viewport_rect()

	if _is_android:
		var margin = touch_edge_scroll_margin
	else:
		var margin = edge_scroll_margin

	if edge_scroll_enabled:
		if mouse_pos.x <= margin:
			direction.x -= 1.0
		elif mouse_pos.x >= viewport_rect.size.x - margin:
			direction.x += 1.0
		if mouse_pos.y <= margin:
			direction.y -= 1.0
		elif mouse_pos.y >= viewport_rect.size.y - margin:
			direction.y += 1.0

	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		var speed = _is_android ? pan_speed * 0.7 : keyboard_pan_speed
		position += direction.normalized() * speed * delta / _current_zoom
		_velocity = Vector2.ZERO
		_clamp_to_map_bounds()
		camera_moved.emit(position)


# =============================================================================
# Screen Shake
# =============================================================================

func _process_shake(delta: float) -> void:
	if not shake_enabled or _shake_timer <= 0.0:
		_shake_offset = Vector2.ZERO
		return

	_shake_timer -= delta
	var progress = 1.0 - (_shake_timer / shake_duration)
	var strength = shake_strength * pow(1.0 - progress, shake_falloff)

	_shake_offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * strength

	position += _shake_offset
	_clamp_to_map_bounds()


# =============================================================================
# Desktop Mouse Fallback
# =============================================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.15, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(0.87, event.position)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_panning = true
				_velocity = Vector2.ZERO
				_pan_start_screen = event.position
				_pan_start_world = _screen_to_world(event.position)
			else:
				_is_panning = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_panning:
		var delta_screen = event.relative
		var delta_world = delta_screen / _current_zoom
		position -= delta_world
		_velocity = -delta_world * 60.0
		_clamp_to_map_bounds()
		camera_moved.emit(position)


# =============================================================================
# Helpers
# =============================================================================

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _zoom_at(factor: float, pivot_screen: Vector2) -> void:
	var world_before = _screen_to_world(pivot_screen)
	_target_zoom = clampf(_target_zoom * factor, min_zoom, max_zoom)
	var world_after = _screen_to_world(pivot_screen)
	position += world_before - world_after
	_clamp_to_map_bounds()


func _center_on_smooth(world_pos: Vector2) -> void:
	follow_enabled = true
	follow_target = null
	_velocity = Vector2.ZERO
	follow_smoothing = 15.0
	call_deferred("_reset_follow")


func _reset_follow() -> void:
	follow_enabled = false
	follow_smoothing = 8.0


func _clamp_to_map_bounds() -> void:
	var viewport_rect = get_viewport_rect()
	var half_view = (viewport_rect.size * 0.5) / _current_zoom
	var min_pos = half_view
	var max_pos = map_size - half_view

	if max_pos.x < min_pos.x:
		min_pos.x = map_size.x * 0.5
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		min_pos.y = map_size.y * 0.5
		max_pos.y = min_pos.y

	position.x = clampf(position.x, min_pos.x, max_pos.x)
	position.y = clampf(position.y, min_pos.y, max_pos.y)


# =============================================================================
# Public API
# =============================================================================

func set_zoom_level(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)


func get_zoom_level() -> float:
	return _target_zoom


func get_current_zoom() -> float:
	return _current_zoom


func set_follow_target(target: Node2D) -> void:
	follow_target = target
	follow_enabled = target != null


func stop_follow() -> void:
	follow_enabled = false
	follow_target = null
	_velocity = Vector2.ZERO


func teleport_to(world_pos: Vector2) -> void:
	_velocity = Vector2.ZERO
	position = world_pos
	_clamp_to_map_bounds()
	camera_moved.emit(position)


func set_map_size(new_size: Vector2) -> void:
	map_size = new_size
	_clamp_to_map_bounds()


func shake(strength: float = -1.0, duration: float = -1.0) -> void:
	if not shake_enabled:
		return
	_shake_current_strength = strength if strength > 0 else shake_strength
	_shake_timer = duration if duration > 0 else shake_duration


func get_viewport_world_rect() -> Rect2:
	var viewport_rect = get_viewport_rect()
	var half_view = (viewport_rect.size * 0.5) / _current_zoom
	return Rect2(position - half_view, viewport_rect.size / _current_zoom)


func is_panning() -> bool:
	return _is_panning or _two_finger_pan_active


func is_pinching() -> bool:
	return _is_pinch_zooming