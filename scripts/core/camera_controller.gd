## Camera2D controller for mobile-friendly RTS gameplay.
##
## Handles single-finger pan with inertia, two-finger pinch zoom,
## double-tap centering, optional target following, and map boundary clamping.
## Attach this script to a Camera2D node in your game scene.
class_name CameraController
extends Camera2D

# =============================================================================
# Configuration
# =============================================================================

## Minimum zoom level (zoomed out). Lower = more zoomed out.
@export var min_zoom: float = 0.3

## Maximum zoom level (zoomed in). Higher = more zoomed out.
@export var max_zoom: float = 2.0

## Speed multiplier for zoom interpolation.
@export var zoom_speed: float = 5.0

## Friction applied to pan velocity each frame (higher = stops sooner).
@export var inertia_friction: float = 8.0

## Pixel distance the camera can pan per second at zoom 1.0.
@export var pan_speed: float = 400.0
@export var keyboard_pan_speed: float = 620.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 18.0

## Map boundaries in pixels. Camera will be clamped inside this rect.
@export var map_size: Vector2 = Vector2(4096, 4096)

## If true, camera will smoothly follow `follow_target`.
@export var follow_enabled: bool = false

## The node (or Vector2) the camera should follow. Must have a `global_position`.
@export var follow_target: Node2D = null

## How quickly the camera lerps toward the follow target (higher = snappier).
@export var follow_smoothing: float = 5.0

## Time window in seconds to detect a double-tap.
@export var double_tap_window: float = 0.3

## Maximum screen-space distance (pixels) between two taps to count as double-tap.
@export var double_tap_tolerance: float = 40.0

# =============================================================================
# Inner Class: Visual Effects Overlay
# =============================================================================

class CameraEffectsOverlay:
	extends Node2D

	var _camera: CameraController = null

	func _init(cam: CameraController) -> void:
		_camera = cam

	func _process(_delta: float) -> void:
		if _camera != null and is_instance_valid(_camera):
			global_position = _camera.global_position
			queue_redraw()

	func _draw() -> void:
		if _camera == null:
			return
		_camera._draw_touch_effects(self)
		_camera._draw_move_arrows(self)

# =============================================================================
# Visual Effect Data
# =============================================================================

class TouchEffect:
	var world_pos: Vector2
	var elapsed: float = 0.0
	var duration: float = 0.35
	var start_radius: float = 8.0
	var end_radius: float = 28.0
	var color: Color = Color(0.2, 0.9, 0.3, 0.8)

	func is_finished() -> bool:
		return elapsed >= duration

	func get_progress() -> float:
		return clampf(elapsed / duration, 0.0, 1.0)

class MoveArrowEffect:
	var world_pos: Vector2
	var direction: Vector2
	var elapsed: float = 0.0
	var duration: float = 0.6
	var color: Color = Color(0.2, 0.9, 0.3, 0.9)
	var _draw_points: PackedVector2Array

	func is_finished() -> bool:
		return elapsed >= duration

	func get_progress() -> float:
		return clampf(elapsed / duration, 0.0, 1.0)

# =============================================================================
# Internal State
# =============================================================================

## Current pan velocity in pixels/sec, applied as inertia on release.
var _velocity: Vector2 = Vector2.ZERO

## Whether the user is currently dragging (at least one finger down).
var _is_panning: bool = false

## World position where the current drag started.
var _drag_start_world: Vector2 = Vector2.ZERO

## Screen position where the current drag started.
var _drag_start_screen: Vector2 = Vector2.ZERO

## Tracks all active touches by index -> screen position.
var _active_touches: Dictionary = {}

## Stored zoom target for smooth interpolation.
var _target_zoom: float = 1.0

## Distance between two fingers at pinch start.
var _pinch_start_distance: float = 0.0

## Zoom level at pinch start.
var _pinch_start_zoom: float = 1.0

## Midpoint of two fingers at pinch start (screen coords).
var _pinch_midpoint: Vector2 = Vector2.ZERO

## Timestamp of last tap (for double-tap detection).
var _last_tap_time: float = 0.0

## Screen position of last tap.
var _last_tap_position: Vector2 = Vector2.ZERO

## Whether a two-finger gesture was active this frame (prevents single-finger processing).
var _two_finger_active: bool = false

## Whether we are currently in a pinch gesture.
var _is_pinching: bool = false
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

## Visual effects overlay node.
var _effects_overlay: CameraEffectsOverlay = null

## Active touch feedback circles.
var _touch_effects: Array[TouchEffect] = []

## Active move-arrow feedback markers.
var _move_arrows: Array[MoveArrowEffect] = []

## Smooth pan target (set by center_on_smooth, lerped in _process).
var _smooth_pan_target: Vector2 = Vector2.ZERO
var _is_smoothing_to_target: bool = false

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	zoom = Vector2.ONE * _target_zoom
	position = map_size * 0.5
	make_current()

	_effects_overlay = CameraEffectsOverlay.new(self)
	_effects_overlay.name = "CameraEffectsOverlay"
	add_child(_effects_overlay)

	EventBus.move_order_feedback.connect(_on_move_order_feedback)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _process(delta: float) -> void:
	position -= _shake_offset
	_shake_offset = Vector2.ZERO

	var current_z: float = zoom.x
	if not is_equal_approx(current_z, _target_zoom):
		zoom = Vector2.ONE * lerpf(current_z, _target_zoom, zoom_speed * delta)
		EventBus.camera_zoomed.emit(_target_zoom)

	if not _is_panning and _velocity.length_squared() > 0.01:
		var decay: float = exp(-inertia_friction * delta)
		_velocity *= decay
		position -= _velocity * delta
		_clamp_to_map_bounds()
		EventBus.camera_moved.emit(position)

	if follow_enabled and follow_target != null and is_instance_valid(follow_target):
		var desired: Vector2 = follow_target.global_position
		position = position.lerp(desired, follow_smoothing * delta)
		_clamp_to_map_bounds()
		EventBus.camera_moved.emit(position)

	if _is_smoothing_to_target:
		var dist_sq: float = position.distance_squared_to(_smooth_pan_target)
		if dist_sq < 4.0:
			position = _smooth_pan_target
			_is_smoothing_to_target = false
			_clamp_to_map_bounds()
			EventBus.camera_moved.emit(position)
		else:
			position = position.lerp(_smooth_pan_target, follow_smoothing * delta)
			_clamp_to_map_bounds()
			EventBus.camera_moved.emit(position)

	_update_keyboard_and_edge_scroll(delta)
	_apply_screen_shake(delta)
	_update_visual_effects(delta)

# =============================================================================
# Touch Handling
# =============================================================================

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var idx: int = event.index

	if event.pressed:
		_active_touches[idx] = event.position

		if _active_touches.size() == 1:
			_is_panning = true
			_velocity = Vector2.ZERO
			_drag_start_screen = event.position
			_drag_start_world = _screen_to_world(event.position)
		elif _active_touches.size() == 2:
			_is_panning = false
			_is_pinching = true
			_two_finger_active = true
			_begin_pinch()
	else:
		_active_touches.erase(idx)

		if _active_touches.size() == 0:
			if _is_pinching:
				_is_pinching = false
				_two_finger_active = false
			elif _is_panning:
				var drag_dist: float = event.position.distance_to(_drag_start_screen)
				if drag_dist < double_tap_tolerance:
					_handle_tap(event.position)
				_is_panning = false
		elif _active_touches.size() == 1:
			_is_pinching = false
			_two_finger_active = false
			var remaining_idx: int = _active_touches.keys()[0]
			_drag_start_screen = _active_touches[remaining_idx]
			_drag_start_world = _screen_to_world(_active_touches[remaining_idx])
			_is_panning = true
			_velocity = Vector2.ZERO


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_active_touches[event.index] = event.position

	if _is_pinching and _active_touches.size() >= 2:
		_update_pinch()
	elif _is_panning and _active_touches.size() == 1:
		var delta_screen: Vector2 = event.relative
		var delta_world: Vector2 = delta_screen / zoom.x
		position -= delta_world
		_velocity = -delta_world * 60.0
		_clamp_to_map_bounds()
		EventBus.camera_moved.emit(position)

# =============================================================================
# Mouse Handling (Desktop Fallback)
# =============================================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom * 1.1, min_zoom, max_zoom)
		MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom * 0.9, min_zoom, max_zoom)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_panning = true
				_velocity = Vector2.ZERO
				_drag_start_screen = event.position
				_drag_start_world = _screen_to_world(event.position)
			else:
				_is_panning = false


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_panning:
		var delta_screen: Vector2 = event.relative
		var delta_world: Vector2 = delta_screen / zoom.x
		position -= delta_world
		_velocity = -delta_world * 60.0
		_clamp_to_map_bounds()
		EventBus.camera_moved.emit(position)

# =============================================================================
# Tap Handling
# =============================================================================

func _handle_tap(tap_screen_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var time_since_last: float = now - _last_tap_time
	var dist_from_last: float = tap_screen_pos.distance_to(_last_tap_position)

	if time_since_last <= double_tap_window and dist_from_last <= double_tap_tolerance:
		var world_pos: Vector2 = _screen_to_world(tap_screen_pos)
		_center_on(world_pos)
		_last_tap_time = 0.0
		_last_tap_position = Vector2.ZERO
	else:
		_last_tap_time = now
		_last_tap_position = tap_screen_pos

# =============================================================================
# Pinch Zoom
# =============================================================================

func _begin_pinch() -> void:
	if _active_touches.size() < 2:
		return
	var positions: Array = _active_touches.values()
	var pos_a: Vector2 = positions[0]
	var pos_b: Vector2 = positions[1]
	_pinch_start_distance = pos_a.distance_to(pos_b)
	_pinch_start_zoom = _target_zoom
	_pinch_midpoint = (pos_a + pos_b) * 0.5


func _update_pinch() -> void:
	if _active_touches.size() < 2:
		return
	var positions: Array = _active_touches.values()
	var pos_a: Vector2 = positions[0]
	var pos_b: Vector2 = positions[1]

	var current_distance: float = pos_a.distance_to(pos_b)
	if _pinch_start_distance <= 0.0:
		return

	var ratio: float = current_distance / _pinch_start_distance
	var new_zoom: float = _pinch_start_zoom * ratio
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)

	var midpoint_world_before: Vector2 = _screen_to_world(_pinch_midpoint)
	zoom = Vector2.ONE * _target_zoom
	var midpoint_world_after: Vector2 = _screen_to_world(_pinch_midpoint)
	position += midpoint_world_before - midpoint_world_after
	_clamp_to_map_bounds()

# =============================================================================
# Visual Effects: Touch Circle + Move Arrow
# =============================================================================

func spawn_touch_effect(world_pos: Vector2) -> void:
	var effect: TouchEffect = TouchEffect.new()
	effect.world_pos = world_pos
	effect.elapsed = 0.0
	_touch_effects.append(effect)


func _on_move_order_feedback(target_pos: Vector2) -> void:
	var units: Array = get_tree().get_nodes_in_group("units")
	var avg_unit_pos: Vector2 = Vector2.ZERO
	var count: int = 0
	for unit: Node in units:
		if unit is Node2D and unit.get("player_id") != null and int(unit.get("player_id")) == GameManager.get_local_player_id():
			avg_unit_pos += (unit as Node2D).global_position
			count += 1
	var dir: Vector2 = Vector2.ZERO
	if count > 0:
		avg_unit_pos /= float(count)
		dir = (target_pos - avg_unit_pos).normalized()
	else:
		dir = Vector2(0, 1)

	var arrow: MoveArrowEffect = MoveArrowEffect.new()
	arrow.world_pos = target_pos
	arrow.direction = dir
	arrow.elapsed = 0.0
	var side: float = 12.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	arrow._draw_points = PackedVector2Array([
		target_pos + dir * side,
		target_pos - perp * side * 0.7,
		target_pos - dir * side * 0.3,
		target_pos + perp * side * 0.7,
	])
	_move_arrows.append(arrow)


func _update_visual_effects(delta: float) -> void:
	var i: int = _touch_effects.size() - 1
	while i >= 0:
		_touch_effects[i].elapsed += delta
		if _touch_effects[i].is_finished():
			_touch_effects.remove_at(i)
		i -= 1

	var j: int = _move_arrows.size() - 1
	while j >= 0:
		_move_arrows[j].elapsed += delta
		if _move_arrows[j].is_finished():
			_move_arrows.remove_at(j)
		j -= 1


func _draw_touch_effects(overlay: Node2D) -> void:
	for effect: TouchEffect in _touch_effects:
		var progress: float = effect.get_progress()
		var radius: float = lerpf(effect.start_radius, effect.end_radius, progress)
		var alpha: float = (1.0 - progress) * effect.color.a
		var c: Color = Color(effect.color.r, effect.color.g, effect.color.b, alpha)
		overlay.draw_arc(effect.world_pos, radius, 0, TAU, 32, c, 2.0, true)


func _draw_move_arrows(overlay: Node2D) -> void:
	for arrow: MoveArrowEffect in _move_arrows:
		var progress: float = arrow.get_progress()
		var alpha: float = (1.0 - progress * progress) * arrow.color.a
		var c: Color = Color(arrow.color.r, arrow.color.g, arrow.color.b, alpha)
		var scale_factor: float = lerpf(0.5, 1.0, progress) if progress < 0.1 else 1.0
		var center: Vector2 = arrow.world_pos
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in arrow._draw_points:
			pts.append(center + (p - center) * scale_factor)
		overlay.draw_colored_polygon(pts, c)

# =============================================================================
# Helpers
# =============================================================================

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _clamp_to_map_bounds() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	var half_view: Vector2 = (viewport_rect.size * 0.5) / zoom.x
	var min_pos: Vector2 = half_view
	var max_pos: Vector2 = map_size - half_view
	if max_pos.x < min_pos.x:
		min_pos.x = map_size.x * 0.5
		max_pos.x = min_pos.x
	if max_pos.y < min_pos.y:
		min_pos.y = map_size.y * 0.5
		max_pos.y = min_pos.y
	position.x = clampf(position.x, min_pos.x, max_pos.x)
	position.y = clampf(position.y, min_pos.y, max_pos.y)


func _update_keyboard_and_edge_scroll(delta: float) -> void:
	if _is_panning or _is_pinching:
		return

	var direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if edge_scroll_enabled:
		var viewport_rect: Rect2 = get_viewport_rect()
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		if viewport_rect.has_point(mouse_pos):
			if mouse_pos.x <= edge_scroll_margin:
				direction.x -= 1.0
			elif mouse_pos.x >= viewport_rect.size.x - edge_scroll_margin:
				direction.x += 1.0
			if mouse_pos.y <= edge_scroll_margin:
				direction.y -= 1.0
			elif mouse_pos.y >= viewport_rect.size.y - edge_scroll_margin:
				direction.y += 1.0

	if direction == Vector2.ZERO:
		return

	position += direction.normalized() * keyboard_pan_speed * delta / zoom.x
	_velocity = Vector2.ZERO
	_clamp_to_map_bounds()
	EventBus.camera_moved.emit(position)


func _center_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_to_map_bounds()
	_velocity = Vector2.ZERO
	EventBus.camera_moved.emit(position)


func center_on_smooth(world_pos: Vector2) -> void:
	_velocity = Vector2.ZERO
	_smooth_pan_target = world_pos
	_is_smoothing_to_target = true

# =============================================================================
# Public API
# =============================================================================

func set_zoom_level(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)


func get_zoom_level() -> float:
	return _target_zoom


func set_follow_target(target: Node2D) -> void:
	follow_target = target
	follow_enabled = target != null


func stop_follow() -> void:
	follow_enabled = false
	follow_target = null
	_velocity = Vector2.ZERO


func teleport_to(world_pos: Vector2) -> void:
	_velocity = Vector2.ZERO
	_center_on(world_pos)


func set_map_size(new_size: Vector2) -> void:
	map_size = new_size
	_clamp_to_map_bounds()


func shake(strength: float = 6.0, duration: float = 0.22) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(duration, 0.01)
	_shake_timer = _shake_duration


func _apply_screen_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		return
	_shake_timer -= delta
	var fade: float = clampf(_shake_timer / _shake_duration, 0.0, 1.0)
	_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * fade
	position += _shake_offset


func recenter_on_army() -> void:
	var local_id: int = GameManager.get_local_player_id()
	var avg_pos: Vector2 = Vector2.ZERO
	var count: int = 0

	var input_mgr: Node = get_node_or_null("/root/GameWorld/InputManager")
	if input_mgr != null and input_mgr.has_method("get_selected_units"):
		var selected: Array[int] = input_mgr.get_selected_units()
		if selected.size() > 0:
			for uid: int in selected:
				var unit: Node2D = _find_unit_by_id(uid)
				if unit != null:
					avg_pos += unit.global_position
					count += 1
			if count > 0:
				avg_pos /= float(count)
				center_on_smooth(avg_pos)
				return

	var units: Array = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit is Node2D and unit.get("player_id") != null and int(unit.get("player_id")) == local_id:
			avg_pos += (unit as Node2D).global_position
			count += 1

	if count > 0:
		avg_pos /= float(count)
		center_on_smooth(avg_pos)


func _find_unit_by_id(unit_id: int) -> Node2D:
	var units: Array = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit is Node2D and unit.get("unit_id") != null and int(unit.get("unit_id")) == unit_id:
			return unit as Node2D
	return null
