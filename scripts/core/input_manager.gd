class_name InputManager
extends Node

# =============================================================================
# Signals
# =============================================================================

signal selection_changed(selected_units: Array, selected_buildings: Array)
signal command_issued(command_type: String, target: Variant, data: Dictionary = {})
signal camera_pan_requested(delta_world: Vector2)
signal camera_zoom_requested(zoom_factor: float, pivot_screen: Vector2)
signal ui_interaction_started()
signal ui_interaction_ended()
signal long_press_detected(screen_pos: Vector2, world_pos: Vector2)
signal touch_indicator_requested(screen_pos: Vector2, indicator_type: String)

# =============================================================================
# Configuration
# =============================================================================

@export var click_threshold: float = 10.0
@export var long_press_time: float = 0.5
@export var double_tap_window: float = 0.3
@export var double_tap_tolerance: float = 20.0
@export var two_finger_pan_threshold: float = 15.0
@export var pinch_threshold: float = 10.0

@export var touch_indicator_duration: float = 0.3
@export var min_touch_target_dp: int = 48

# Android detection
var is_android: bool = OS.get_name() == "Android"

# =============================================================================
# Internal State
# =============================================================================

var _active_touches: Dictionary = {}
var _touch_start_times: Dictionary = {}
var _touch_start_positions: Dictionary = {}
var _long_press_timers: Dictionary = {}
var _is_selecting: bool = false
var _selection_start_screen: Vector2 = Vector2.ZERO
var _selection_start_world: Vector2 = Vector2.ZERO
var _last_tap_time: float = 0.0
var _last_tap_screen: Vector2 = Vector2.ZERO
var _is_panning_camera: bool = false
var _pan_start_screen: Vector2 = Vector2.ZERO
var _is_pinch_zooming: bool = false
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pinch_midpoint_screen: Vector2 = Vector2.ZERO
var _ui_interaction_active: bool = false
var _camera_controller: CameraController = null
var _selection_manager: Node = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_process_mode = Node.PROCESS_MODE_ALWAYS
	_camera_controller = get_node_or_null("/root/GameWorld/CameraController")
	if _camera_controller == null:
		_camera_controller = get_node_or_null("/root/CameraController")
	_selection_manager = get_node_or_null("/root/GameWorld/SelectionManager")
	if _selection_manager == null:
		_selection_manager = get_node_or_null("/root/SelectionManager")

	if is_android:
		OS.set_touchscreen_emulator_enabled(false)
		OS.set_virtual_keyboard_enabled(false)

	Input.use_accumulated_input = false


func _process(delta: float) -> void:
	if is_android:
		_check_long_press_timers(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _is_ui_interaction(event):
		_ui_interaction_active = true
		_ui_interaction_started.emit()
		return

	if is_android:
		if event is InputEventScreenTouch:
			_handle_screen_touch(event)
		elif event is InputEventScreenDrag:
			_handle_screen_drag(event)
	else:
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
		elif event is InputEventMouseMotion:
			_handle_mouse_motion(event)


func _input(event: InputEvent) -> void:
	if _ui_interaction_active and event is InputEventMouseButton and not event.pressed:
		_ui_interaction_active = false
		_ui_interaction_ended.emit()
	elif event is InputEventScreenTouch and not event.pressed:
		_ui_interaction_active = false
		_ui_interaction_ended.emit()


# =============================================================================
# UI Interaction Priority
# =============================================================================

func _is_ui_interaction(event: InputEvent) -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false

	var gui = viewport.gui_get_focus_owner()
	if gui != null:
		return true

	var mouse_pos = viewport.get_mouse_position()
	var controls_at_pos = viewport.gui_get_drag_data(mouse_pos)
	if controls_at_pos:
		return true

	return false


# =============================================================================
# Android Touch Handling
# =============================================================================

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var idx = event.index

	if event.pressed:
		_touch_start_times[idx] = Time.get_ticks_msec() / 1000.0
		_touch_start_positions[idx] = event.position
		_active_touches[idx] = event.position

		_long_press_timers[idx] = _touch_start_times[idx] + long_press_time

		_touch_indicator_requested.emit(event.position, "touch_down")

		if _active_touches.size() == 1:
			_selection_start_screen = event.position
			_selection_start_world = _screen_to_world(event.position)
			_is_selecting = false
			_is_panning_camera = false
		elif _active_touches.size() == 2:
			_begin_two_finger_pan()
			_begin_pinch_zoom()
	else:
		_handle_touch_end(idx, event.position)
		_active_touches.erase(idx)
		_touch_start_times.erase(idx)
		_touch_start_positions.erase(idx)
		_long_press_timers.erase(idx)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_active_touches[event.index] = event.position

	if _is_pinch_zooming and _active_touches.size() >= 2:
		_update_pinch_zoom()
		return

	if _active_touches.size() == 2:
		_update_two_finger_pan()
		return

	if _active_touches.size() == 1:
		var idx = _active_touches.keys()[0]
		var drag_distance = event.position.distance_to(_touch_start_positions[idx])

		if _is_panning_camera:
			var delta_screen = event.relative
			var delta_world = delta_screen / _camera_controller.zoom.x
			_camera_pan_requested.emit(-delta_world)
			return

		if not _is_selecting and drag_distance > click_threshold:
			if _is_selection_gesture(idx):
				_is_selecting = true
				_selection_start_screen = _touch_start_positions[idx]
				_selection_start_world = _screen_to_world(_touch_start_positions[idx])
			else:
				_is_panning_camera = true
				_pan_start_screen = event.position

		if _is_selecting:
			_update_selection_box(event.position)
		elif _is_panning_camera:
			var delta_screen = event.relative
			var delta_world = delta_screen / _camera_controller.zoom.x
			_camera_pan_requested.emit(-delta_world)


func _handle_touch_end(idx: int, screen_pos: Vector2) -> void:
	var touch_duration = (Time.get_ticks_msec() / 1000.0) - _touch_start_times.get(idx, 0)
	var drag_distance = screen_pos.distance_to(_touch_start_positions.get(idx, screen_pos))

	if _is_pinch_zooming and _active_touches.size() <= 2:
		_end_pinch_zoom()
		return

	if _active_touches.size() == 2 and not _is_pinch_zooming:
		_end_two_finger_pan()
		return

	if drag_distance <= click_threshold and touch_duration < long_press_time:
		_handle_tap(screen_pos, _touch_start_times[idx])
	elif drag_distance > click_threshold:
		if _is_selecting:
			_finalize_selection(screen_pos)
		elif _is_panning_camera:
			_is_panning_camera = false
	_is_selecting = false
	_is_panning_camera = false


func _check_long_press_timers(delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	for idx in _long_press_timers.keys():
		if current_time >= _long_press_timers[idx]:
			var screen_pos = _active_touches.get(idx, Vector2.ZERO)
			var world_pos = _screen_to_world(screen_pos)
			_long_press_detected.emit(screen_pos, world_pos)
			_touch_indicator_requested.emit(screen_pos, "long_press")
			_long_press_timers.erase(idx)
			break


# =============================================================================
# Gesture Detection
# =============================================================================

func _is_selection_gesture(idx: int) -> bool:
	var start_pos = _touch_start_positions.get(idx, Vector2.ZERO)
	var resource_at_start = _find_resource_at_screen(start_pos)
	var unit_at_start = _find_unit_at_screen(start_pos)
	var building_at_start = _find_building_at_screen(start_pos)

	if resource_at_start or unit_at_start or building_at_start:
		return false

	if _selection_manager != null and _selection_manager.has_method("has_selection"):
		if _selection_manager.has_selection():
			return false

	return true


func _begin_two_finger_pan() -> void:
	_is_panning_camera = true
	var positions = _active_touches.values()
	_pan_start_screen = (positions[0] + positions[1]) * 0.5


func _update_two_finger_pan() -> void:
	if _active_touches.size() < 2:
		return
	var positions = _active_touches.values()
	var current_mid = (positions[0] + positions[1]) * 0.5
	var delta_screen = current_mid - _pan_start_screen

	if delta_screen.length() > two_finger_pan_threshold:
		var delta_world = delta_screen / _camera_controller.zoom.x
		_camera_pan_requested.emit(-delta_world)
		_pan_start_screen = current_mid


func _end_two_finger_pan() -> void:
	_is_panning_camera = false


func _begin_pinch_zoom() -> void:
	_is_pinch_zooming = true
	_is_panning_camera = false
	var positions = _active_touches.values()
	var pos_a = positions[0]
	var pos_b = positions[1]
	_pinch_start_distance = pos_a.distance_to(pos_b)
	_pinch_start_zoom = _camera_controller.get_zoom_level()
	_pinch_midpoint_screen = (pos_a + pos_b) * 0.5


func _update_pinch_zoom() -> void:
	if _active_touches.size() < 2:
		return
	var positions = _active_touches.values()
	var pos_a = positions[0]
	var pos_b = positions[1]
	var current_distance = pos_a.distance_to(pos_b)

	if abs(current_distance - _pinch_start_distance) > pinch_threshold:
		var ratio = current_distance / _pinch_start_distance
		var new_zoom = _pinch_start_zoom * ratio
		new_zoom = clampf(new_zoom, _camera_controller.min_zoom, _camera_controller.max_zoom)
		_camera_zoom_requested.emit(new_zoom / _camera_controller.get_zoom_level(), _pinch_midpoint_screen)


func _end_pinch_zoom() -> void:
	_is_pinch_zooming = false


# =============================================================================
# Tap Handling
# =============================================================================

func _handle_tap(screen_pos: Vector2, tap_time: float) -> void:
	var time_since_last = tap_time - _last_tap_time
	var dist_from_last = screen_pos.distance_to(_last_tap_screen)

	if time_since_last <= double_tap_window and dist_from_last <= double_tap_tolerance:
		_handle_double_tap(screen_pos)
		_last_tap_time = 0
		_last_tap_screen = Vector2.ZERO
	else:
		_handle_single_tap(screen_pos)
		_last_tap_time = tap_time
		_last_tap_screen = screen_pos

	_touch_indicator_requested.emit(screen_pos, "tap")


func _handle_single_tap(screen_pos: Vector2) -> void:
	var world_pos = _screen_to_world(screen_pos)

	var unit = _find_unit_at_screen(screen_pos)
	if unit != null:
		_select_unit(unit)
		return

	var building = _find_building_at_screen(screen_pos)
	if building != null:
		_select_building(building)
		return

	if _selection_manager != null and _selection_manager.has_method("has_selection"):
		if _selection_manager.has_selection():
			var resource = _find_resource_at_screen(screen_pos)
			if resource != null:
				_command_issued.emit("harvest", resource, {"target_pos": world_pos})
				return

			_command_issued.emit("move", world_pos, {})
			return
	_select_building_at(world_pos)


func _handle_double_tap(screen_pos: Vector2) -> void:
	var world_pos = _screen_to_world(screen_pos)
	_camera_controller.center_on_smooth(world_pos)
	_touch_indicator_requested.emit(screen_pos, "double_tap")


# =============================================================================
# Selection Box
# =============================================================================

func _update_selection_box(current_screen: Vector2) -> void:
	if _selection_manager == null:
		return
	var rect = Rect2(
		Vector2(min(_selection_start_screen.x, current_screen.x), min(_selection_start_screen.y, current_screen.y)),
		Vector2(abs(current_screen.x - _selection_start_screen.x), abs(current_screen.y - _selection_start_screen.y))
	)
	_selection_manager.select_units_in_rect(rect)


func _finalize_selection(screen_pos: Vector2) -> void:
	if _selection_manager != null and _selection_manager.has_method("finalize_selection"):
		_selection_manager.finalize_selection()
	_selection_manager.get_selected_units()


# =============================================================================
# Desktop Mouse Fallback
# =============================================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_times[-1] = Time.get_ticks_msec() / 1000.0
			_touch_start_positions[-1] = event.position
			_selection_start_screen = event.position
			_selection_start_world = _screen_to_world(event.position)
			_is_selecting = false
		else:
			var drag_dist = event.position.distance_to(_selection_start_screen)
			if drag_dist <= click_threshold:
				_handle_tap(event.position, _touch_start_times[-1])
			elif _is_selecting:
				_finalize_selection(event.position)
			_is_selecting = false
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_is_panning_camera = true
			_pan_start_screen = event.position
		else:
			_is_panning_camera = false
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_camera_zoom_requested.emit(1.1, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_camera_zoom_requested.emit(0.9, event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_panning_camera:
		var delta_world = event.relative / _camera_controller.zoom.x
		_camera_pan_requested.emit(-delta_world)
	elif _is_selecting:
		var drag_dist = event.position.distance_to(_selection_start_screen)
		if drag_dist > click_threshold:
			_update_selection_box(event.position)


# =============================================================================
# Selection Helpers
# =============================================================================

func _select_unit(unit: Node) -> void:
	if _selection_manager != null and _selection_manager.has_method("select_unit"):
		_selection_manager.select_unit(unit)
	_selection_changed.emit(_get_selected_units(), _get_selected_buildings())


func _select_building(building: Node) -> void:
	if _selection_manager != null and _selection_manager.has_method("select_building"):
		_selection_manager.select_building(building)
	_selection_changed.emit(_get_selected_units(), _get_selected_buildings())


func _select_building_at(world_pos: Vector2) -> void:
	if _selection_manager != null and _selection_manager.has_method("select_building_at"):
		_selection_manager.select_building_at(world_pos)
	_selection_changed.emit(_get_selected_units(), _get_selected_buildings())


func _get_selected_units() -> Array:
	if _selection_manager != null and _selection_manager.has_method("get_selected_units"):
		return _selection_manager.get_selected_units()
	return []


func _get_selected_buildings() -> Array:
	if _selection_manager != null and _selection_manager.has_method("get_selected_buildings"):
		return _selection_manager.get_selected_buildings()
	return []


# =============================================================================
# Spatial Queries
# =============================================================================

func _find_unit_at_screen(screen_pos: Vector2) -> Node:
	var world_pos = _screen_to_world(screen_pos)
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit is Node2D and unit.has_method("get_rect"):
			var rect = unit.get_rect()
			if rect.has_point(unit.to_local(world_pos)):
				return unit
	return null


func _find_building_at_screen(screen_pos: Vector2) -> Node:
	var world_pos = _screen_to_world(screen_pos)
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building is Node2D and building.has_method("get_rect"):
			var rect = building.get_rect()
			if rect.has_point(building.to_local(world_pos)):
				return building
	return null


func _find_resource_at_screen(screen_pos: Vector2) -> Node:
	var world_pos = _screen_to_world(screen_pos)
	var resources = get_tree().get_nodes_in_group("resources")
	var best = null
	var best_dist_sq = 10000.0
	for resource in resources:
		if resource is Node2D:
			var dist_sq = resource.global_position.distance_squared_to(world_pos)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best = resource
	return best


# =============================================================================
# Helpers
# =============================================================================

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if _camera_controller != null:
		return _camera_controller.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos


func _get_viewport_rect() -> Rect2:
	return get_viewport_rect()


func is_selecting() -> bool:
	return _is_selecting


func get_selection_rect() -> Rect2:
	if not _is_selecting:
		return Rect2()
	var current_pos = _active_touches.values().size() > 0 ? _active_touches.values()[0] : _selection_start_screen
	return Rect2(
		Vector2(min(_selection_start_screen.x, current_pos.x), min(_selection_start_screen.y, current_pos.y)),
		Vector2(abs(current_pos.x - _selection_start_screen.x), abs(current_pos.y - _selection_start_screen.y))
	)


func get_selection_rect_world() -> Rect2:
	var start_w = _selection_start_world
	var end_w = _screen_to_world(_active_touches.values().size() > 0 ? _active_touches.values()[0] : _selection_start_screen)
	return Rect2(
		Vector2(min(start_w.x, end_w.x), min(start_w.y, end_w.y)),
		Vector2(abs(end_w.x - start_w.x), abs(end_w.y - start_w.y))
	)


func set_camera_controller(camera: CameraController) -> void:
	_camera_controller = camera