## Manages all player input and translates it into game actions.
##
## Handles single-tap selection, right-click/long-press commands, drag-selection
## boxes for multi-select, build-mode placement, and coordinate conversion
## between screen and world space. Attach to a Node in your main game scene.
class_name InputManager
extends Node

# =============================================================================
# Configuration
# =============================================================================

## Screen-space distance (pixels) below which a press+release counts as a click.
@export var click_threshold: float = 10.0

## How long (seconds) a press must be held before it counts as a long press.
@export var long_press_duration: float = 0.4

## Color of the selection rectangle rubber-band.
@export var selection_box_color: Color = Color(0.2, 0.8, 0.2, 0.3)

## Border color of the selection rectangle.
@export var selection_box_border_color: Color = Color(0.2, 0.8, 0.2, 0.8)

## Width (pixels) of the selection rectangle border.
@export var selection_box_border_width: float = 2.0

# =============================================================================
# State
# =============================================================================

## World position where the current press began.
var _press_start_world: Vector2 = Vector2.ZERO

## Screen position where the current press began.
var _press_start_screen: Vector2 = Vector2.ZERO

## Current mouse / finger position in screen coordinates.
var _current_screen_pos: Vector2 = Vector2.ZERO

## Current mouse position in world coordinates (updated every frame).
var mouse_world_position: Vector2 = Vector2.ZERO

## Whether the user has dragged beyond click_threshold this press.
var _has_dragged: bool = false

## Whether a press is currently active.
var _is_pressed: bool = false

## Timestamp when the current press began.
var _press_start_time: float = 0.0

## Whether we are currently in build mode (placing a building).
var has_build_mode: bool = false

## The building type being placed in build mode.
var build_mode_type: String = ""

## Whether attack-move mode is active (A key pressed, awaiting target).
var has_attack_move_mode: bool = false

## Whether patrol mode is active (P key pressed, awaiting 2 clicks).
var has_patrol_mode: bool = false
var _patrol_click_count: int = 0
var _patrol_point_a: Vector2 = Vector2.ZERO

## Reference to the Camera2D used for coordinate conversion.
var _camera: Camera2D = null

## The selection rectangle node (drawn on a CanvasLayer above the world).
var _selection_rect: Control = null

## CanvasLayer that holds the selection rect so it stays on screen.
var _selection_layer: CanvasLayer = null

## Whether we are currently drawing the selection rectangle.
var _is_selecting: bool = false

## Screen position of the selection box origin.
var _selection_origin_screen: Vector2 = Vector2.ZERO

## IDs of units currently selected by the player.
var selected_unit_ids: Array[int] = []

## IDs of buildings currently selected by the player.
var selected_building_ids: Array[int] = []

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_setup_selection_rect()


func _process(_delta: float) -> void:
	# Continuously update the world position of the mouse / primary finger.
	if _camera != null:
		mouse_world_position = _camera.get_global_mouse_position()
	elif has_node("/root/GameWorld/Camera2D"):
		_camera = get_node("/root/GameWorld/Camera2D")
		mouse_world_position = _camera.get_global_mouse_position()

	# Update the selection rectangle visual if actively selecting.
	if _is_selecting:
		_update_selection_rect_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)

# =============================================================================
# Input Handling — Touch
# =============================================================================

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_press_start_screen = event.position
		_press_start_world = _screen_to_world(event.position)
		_current_screen_pos = event.position
		_is_pressed = true
		_has_dragged = false
		_press_start_time = Time.get_ticks_msec() / 1000.0
	else:
		_current_screen_pos = event.position
		if _is_pressed:
			_process_release(event.position)
		_is_pressed = false


func _handle_drag(event: InputEventScreenDrag) -> void:
	_current_screen_pos = event.position

	if not _is_pressed:
		return

	var dist: float = event.position.distance_to(_press_start_screen)
	if dist > click_threshold:
		if not _has_dragged:
			_has_dragged = true
			# Check for long press threshold.
			var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _press_start_time
			if elapsed >= long_press_duration or has_build_mode:
				if not has_build_mode:
					_begin_selection_box()
			else:
				# Started dragging before long press — could become a selection box
				# once the long press time is reached.
				pass

		if _is_selecting:
			_update_selection_rect_visual()

# =============================================================================
# Input Handling — Mouse (Desktop Fallback)
# =============================================================================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# We only care about left and right mouse buttons.
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_start_screen = event.position
				_press_start_world = _screen_to_world(event.position)
				_current_screen_pos = event.position
				_is_pressed = true
				_has_dragged = false
				_press_start_time = Time.get_ticks_msec() / 1000.0
			else:
				_current_screen_pos = event.position
				if _is_pressed:
					_process_release(event.position)
				_is_pressed = false

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_handle_right_click(_screen_to_world(event.position))
			else:
				# Right click release — cancel build mode if active.
				if has_build_mode:
					cancel_build_mode()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	_current_screen_pos = event.position
	if _camera != null:
		mouse_world_position = _camera.get_global_mouse_position()

	if _is_pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var dist: float = event.position.distance_to(_press_start_screen)
		if dist > click_threshold:
			if not _has_dragged:
				_has_dragged = true
				_begin_selection_box()
			if _is_selecting:
				_update_selection_rect_visual()

# =============================================================================
# Input Handling — Keyboard
# =============================================================================

func _handle_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE:
			if has_build_mode:
				cancel_build_mode()
			elif has_attack_move_mode:
				cancel_attack_move_mode()
			elif has_patrol_mode:
				cancel_patrol_mode()
			else:
				deselect_all()
		KEY_B:
			EventBus.button_pressed.emit("build_menu", GameManager.get_local_player_id())
		KEY_A:
			if not has_build_mode:
				enter_attack_move_mode()
		KEY_P:
			if not has_build_mode:
				enter_patrol_mode()
		KEY_S:
			EventBus.button_pressed.emit("stop_command", GameManager.get_local_player_id())
		KEY_H:
			_issue_hold_position()
		KEY_W:
			EventBus.button_pressed.emit("gather_wood", GameManager.get_local_player_id())
		KEY_F:
			EventBus.button_pressed.emit("gather_food", GameManager.get_local_player_id())
		KEY_T:
			EventBus.button_pressed.emit("gather_stone", GameManager.get_local_player_id())
		KEY_G:
			EventBus.button_pressed.emit("gather_gold", GameManager.get_local_player_id())
		KEY_V:
			EventBus.button_pressed.emit("train_villager", GameManager.get_local_player_id())
		KEY_Z:
			EventBus.button_pressed.emit("train_swordsman", GameManager.get_local_player_id())
		KEY_X:
			EventBus.button_pressed.emit("train_spearman", GameManager.get_local_player_id())
		KEY_R:
			EventBus.button_pressed.emit("train_archer", GameManager.get_local_player_id())
		KEY_C:
			EventBus.button_pressed.emit("train_cavalry", GameManager.get_local_player_id())
		KEY_SPACE:
			_recenter_camera_on_army()

# =============================================================================
# Release Processing
# =============================================================================

## Process the end of a press (click or drag-release).
func _process_release(release_screen_pos: Vector2) -> void:
	var drag_distance: float = release_screen_pos.distance_to(_press_start_screen)

	if _is_selecting:
		_end_selection_box()
		return

	if drag_distance < click_threshold and not _has_dragged:
		# This was a click / tap.
		if has_build_mode:
			_handle_build_click(release_screen_pos)
		else:
			_handle_click(release_screen_pos)
	elif _has_dragged:
		# Drag ended without entering selection mode (short drag).
		# Still end selection if we were in one.
		pass

# =============================================================================
# Click Handling
# =============================================================================

## Process a click/tap at the given screen position — select unit or building.
func _handle_click(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	EventBus.button_pressed.emit("click", GameManager.get_local_player_id())
	_spawn_click_feedback(screen_pos)

	var selection_manager: Node = _find_selection_manager()
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	if selection_manager != null and selection_manager.has_method("handle_click_at"):
		selection_manager.handle_click_at(world_pos, shift_held)
		_sync_selection_from_manager(selection_manager)
	else:
		deselect_all()


## Process a right-click / long-press command at the given world position.
func _handle_right_click(world_pos: Vector2) -> void:
	if has_build_mode:
		cancel_build_mode()
		return

	if has_attack_move_mode and selected_unit_ids.size() > 0:
		_issue_attack_move(world_pos)
		cancel_attack_move_mode()
		return

	if has_patrol_mode and selected_unit_ids.size() > 0:
		_handle_patrol_click(world_pos)
		return

	if selected_unit_ids.size() > 0:
		var target_resource: Node2D = _find_resource_at_position(world_pos)
		
		var formation_manager: Node = get_node_or_null("/root/GameWorld/FormationManager")
		var units: Array[Node2D] = []
		for unit_id in selected_unit_ids:
			var unit: Node2D = _find_unit_by_id(unit_id)
			if unit:
				units.append(unit)
		
		if target_resource != null:
			for unit: Node2D in units:
				unit.set("pending_target_resource", target_resource)
				var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
				if state_machine != null and state_machine.has_method("change_state"):
					state_machine.change_state("HarvestState")
			EventBus.move_order_feedback.emit(target_resource.global_position)
		elif units.size() > 0:
			if formation_manager and formation_manager.has_method("apply_formation_to_units"):
				var center_pos: Vector2 = Vector2.ZERO
				for u in units:
					center_pos += u.global_position
				center_pos /= units.size()
				
				formation_manager.apply_formation_to_units(units, world_pos, center_pos)
			else:
				var formation_targets: Dictionary = _build_formation_targets(world_pos, units.size())
				for i in range(units.size()):
					var move_target: Vector2 = formation_targets.get(i, world_pos)
					var unit: Node2D = units[i]
					unit.set("pending_move_position", move_target)
					var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
					if state_machine != null and state_machine.has_method("change_state"):
						state_machine.change_state("MoveState")
					EventBus.unit_moved.emit(selected_unit_ids[i], move_target)
			EventBus.move_order_feedback.emit(world_pos)
		AudioManager.play_ui_click()

# =============================================================================
# Build Mode
# =============================================================================

## Process a click while in build mode — attempt to place the building.
func _handle_build_click(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	var grid_manager: Node = get_node_or_null("/root/GameWorld/GridManager")
	if grid_manager == null:
		push_warning("InputManager: GridManager not found for build placement.")
		return

	# Convert world position to grid cell.
	var cell: Vector2i = grid_manager.get_cell_from_world(world_pos)

	# Look up building size from DataManager.
	var building_data: Dictionary = DataManager.get_building_data(build_mode_type)
	var raw_size: Variant = building_data.get("size", {"x": 2, "y": 2})
	var size: Vector2i
	if raw_size is Vector2i:
		size = raw_size
	elif raw_size is Dictionary:
		size = Vector2i(int(raw_size.get("x", 2)), int(raw_size.get("y", 2)))
	else:
		size = Vector2i(2, 2)

	if grid_manager.is_buildable(cell, size):
		var cost: Dictionary = building_data.get("cost", {})
		var player_id: int = GameManager.get_local_player_id()
		if GameManager.spend_resources(cost, player_id):
			var building_manager: Node = _find_building_manager()
			var building_node: Node2D = null
			if building_manager != null and building_manager.has_method("place_building"):
				building_node = building_manager.place_building(build_mode_type, cell, player_id)
			elif grid_manager.has_method("place_building"):
				grid_manager.place_building(cell, size, build_mode_type)

			if building_node != null and building_node.has_method("start_construction"):
				building_node.start_construction()

			AudioManager.play_sfx("res://audio/sfx/build_place.wav")
		else:
			AudioManager.play_sfx("res://audio/sfx/cant_build.wav")
	else:
		AudioManager.play_sfx("res://audio/sfx/cant_build.wav")


## Enter build mode with the given building type.
func enter_build_mode(building_type: String) -> void:
	has_build_mode = true
	build_mode_type = building_type
	deselect_all()
	EventBus.menu_opened.emit("build_mode")


## Exit build mode without placing anything.
func cancel_build_mode() -> void:
	has_build_mode = false
	build_mode_type = ""
	EventBus.menu_closed.emit("build_mode")


## Enter attack-move mode — next right-click issues attack-move command.
func enter_attack_move_mode() -> void:
	has_attack_move_mode = true
	AudioManager.play_ui_click()


## Cancel attack-move mode without issuing a command.
func cancel_attack_move_mode() -> void:
	has_attack_move_mode = false


## Issue attack-move command to all selected units toward world_pos.
func _issue_attack_move(world_pos: Vector2) -> void:
	for uid: int in selected_unit_ids:
		var unit: Node2D = _find_unit_by_id(uid)
		if unit == null:
			continue
		unit.set("pending_attack_move_position", world_pos)
		unit.set("pending_move_position", Vector2.ZERO)
		unit.set("pending_target_resource", null)
		unit.set("pending_target_building", null)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("AttackMoveState")
	EventBus.move_order_feedback.emit(world_pos)
	AudioManager.play_ui_click()


## Enter patrol mode — next two right-clicks set patrol waypoints.
func enter_patrol_mode() -> void:
	has_patrol_mode = true
	_patrol_click_count = 0
	_patrol_point_a = Vector2.ZERO
	AudioManager.play_ui_click()


## Cancel patrol mode without issuing a command.
func cancel_patrol_mode() -> void:
	has_patrol_mode = false
	_patrol_click_count = 0
	_patrol_point_a = Vector2.ZERO


## Handle a click during patrol mode.
func _handle_patrol_click(world_pos: Vector2) -> void:
	if _patrol_click_count == 0:
		var unit: Node2D = _find_unit_by_id(selected_unit_ids[0])
		if unit != null:
			_patrol_point_a = unit.global_position
		else:
			_patrol_point_a = world_pos
		_patrol_click_count = 1
		AudioManager.play_ui_click()
	else:
		var point_b: Vector2 = world_pos
		_issue_patrol(point_b)
		cancel_patrol_mode()


## Issue patrol command to all selected units.
func _issue_patrol(point_b: Vector2) -> void:
	for uid: int in selected_unit_ids:
		var unit: Node2D = _find_unit_by_id(uid)
		if unit == null:
			continue
		var a: Vector2 = _patrol_point_a
		var unit_pos: Vector2 = unit.global_position
		if a.distance_squared_to(unit_pos) > 16.0:
			a = unit_pos
		unit.set("pending_patrol_points", {"a": a, "b": point_b})
		unit.set("pending_move_position", Vector2.ZERO)
		unit.set("pending_attack_move_position", Vector2.ZERO)
		unit.set("pending_target_resource", null)
		unit.set("pending_target_building", null)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("PatrolState")
	EventBus.move_order_feedback.emit(point_b)
	AudioManager.play_ui_click()


## Issue hold position command to all selected units.
func _issue_hold_position() -> void:
	for uid: int in selected_unit_ids:
		var unit: Node2D = _find_unit_by_id(uid)
		if unit == null:
			continue
		unit.set("pending_hold_position", true)
		unit.set("pending_move_position", Vector2.ZERO)
		unit.set("pending_attack_move_position", Vector2.ZERO)
		unit.set("pending_patrol_points", {})
		unit.set("pending_target_resource", null)
		unit.set("pending_target_building", null)
		var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
		if state_machine != null and state_machine.has_method("change_state"):
			state_machine.change_state("HoldPositionState")
	AudioManager.play_ui_click()


## Generate a unique building ID. In production, delegate to a world entity manager.
func _generate_building_id() -> int:
	return randi()

# =============================================================================
# Selection Box (Rubber Band)
# =============================================================================

## Set up the selection rectangle UI elements.
func _setup_selection_rect() -> void:
	_selection_layer = CanvasLayer.new()
	_selection_layer.layer = 100
	_selection_layer.name = "SelectionLayer"
	add_child(_selection_layer)

	_selection_rect = Control.new()
	_selection_rect.name = "SelectionRect"
	_selection_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_selection_layer.add_child(_selection_rect)

	# Connect the draw signal to our custom draw function.
	_selection_rect.draw.connect(_draw_selection_rect)


## Begin drawing the selection box.
func _begin_selection_box() -> void:
	_is_selecting = true
	_selection_origin_screen = _press_start_screen
	EventBus.selection_started.emit(_press_start_world)


## Update the selection rectangle visual each frame.
func _update_selection_rect_visual() -> void:
	if _selection_rect != null:
		_selection_rect.queue_redraw()


## Draw the selection rectangle on screen.
func _draw_selection_rect() -> void:
	if not _is_selecting:
		return
	var origin: Vector2 = _selection_origin_screen
	var current: Vector2 = _current_screen_pos
	var rect: Rect2 = Rect2(origin, current - origin).abs()

	_selection_rect.draw_rect(rect, selection_box_color, true)
	_selection_rect.draw_rect(rect, selection_box_border_color, false, selection_box_border_width)


## Finish the selection box and select all units within it.
func _end_selection_box() -> void:
	_is_selecting = false
	_selection_rect.queue_redraw()

	var start_world: Vector2 = _press_start_world
	var end_world: Vector2 = _screen_to_world(_current_screen_pos)

	var selection_rect_world: Rect2 = Rect2(
		Vector2(minf(start_world.x, end_world.x), minf(start_world.y, end_world.y)),
		Vector2(absf(end_world.x - start_world.x), absf(end_world.y - start_world.y))
	)

	var selection_manager: Node = _find_selection_manager()
	if selection_manager != null and selection_manager.has_method("select_all_in_rect"):
		var selected: Array = selection_manager.select_all_in_rect(selection_rect_world)
		_sync_selection_from_manager(selection_manager)
		EventBus.selection_ended.emit(start_world, end_world, selected)
	else:
		EventBus.selection_ended.emit(start_world, end_world, [])
		deselect_all()

# =============================================================================
# Selection Management
# =============================================================================

## Select an array of unit IDs, replacing any current selection.
func _select_units(unit_ids: Array[int]) -> void:
	deselect_all()
	selected_unit_ids = unit_ids.duplicate()
	for uid: int in selected_unit_ids:
		var player_id: int = GameManager.get_local_player_id()
		EventBus.unit_selected.emit(uid, player_id)
	EventBus.selection_changed.emit(selected_unit_ids, selected_building_ids)


## Add a unit to the current selection (for ctrl+click additive select).
func add_to_selection(unit_id: int) -> void:
	if unit_id not in selected_unit_ids:
		selected_unit_ids.append(unit_id)
		var player_id: int = GameManager.get_local_player_id()
		EventBus.unit_selected.emit(unit_id, player_id)
	EventBus.selection_changed.emit(selected_unit_ids, selected_building_ids)


## Remove a unit from the current selection.
func remove_from_selection(unit_id: int) -> void:
	selected_unit_ids.erase(unit_id)
	var player_id: int = GameManager.get_local_player_id()
	EventBus.unit_deselected.emit(unit_id, player_id)
	EventBus.selection_changed.emit(selected_unit_ids, selected_building_ids)


## Select a building, replacing current selection.
func select_building(building_id: int) -> void:
	deselect_all()
	selected_building_ids.append(building_id)
	var player_id: int = GameManager.get_local_player_id()
	EventBus.building_selected.emit(building_id, player_id)
	EventBus.selection_changed.emit(selected_unit_ids, selected_building_ids)


## Clear all selections.
func deselect_all() -> void:
	var player_id: int = GameManager.get_local_player_id()
	for uid: int in selected_unit_ids:
		EventBus.unit_deselected.emit(uid, player_id)
	selected_unit_ids.clear()
	selected_building_ids.clear()
	EventBus.selection_changed.emit(selected_unit_ids, selected_building_ids)


## Get the list of currently selected unit IDs.
func get_selected_units() -> Array[int]:
	return selected_unit_ids


## Get the list of currently selected building IDs.
func get_selected_buildings() -> Array[int]:
	return selected_building_ids


## Check if any selection is active.
func has_selection() -> bool:
	return selected_unit_ids.size() > 0 or selected_building_ids.size() > 0

# =============================================================================
# Coordinate Conversion
# =============================================================================

## Convert a screen-space position to world-space using the camera.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if _camera != null:
		return _camera.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos


func _find_selection_manager() -> Node:
	var node: Node = get_node_or_null("/root/GameWorld/SelectionManager")
	if node != null:
		return node
	return get_node_or_null("/root/GameWorld/World/SelectionManager")


func _find_building_manager() -> Node:
	var node: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if node != null:
		return node
	return get_node_or_null("/root/GameWorld/World/BuildingManager")


func _sync_selection_from_manager(selection_manager: Node) -> void:
	if selection_manager == null:
		return
	if selection_manager.has_method("get_selected_units"):
		selected_unit_ids = selection_manager.get_selected_units()
	if selection_manager.has_method("get_selected_building"):
		var selected_building: int = selection_manager.get_selected_building()
		selected_building_ids = []
		if selected_building != -1:
			selected_building_ids.append(selected_building)
	elif selection_manager.has_method("get_selected_buildings"):
		selected_building_ids = selection_manager.get_selected_buildings()


func _find_unit_by_id(unit_id: int) -> Node2D:
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit: Node in units:
		if unit is Node2D and unit.get("unit_id") != null and int(unit.get("unit_id")) == unit_id:
			return unit as Node2D
	return null


func _find_resource_at_position(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = 56.0 * 56.0
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _find_resource_recursive(root, world_pos, best, best_dist_sq)


func _find_resource_recursive(node: Node, world_pos: Vector2, best: Node2D, best_dist_sq: float) -> Node2D:
	if node is Node2D and node.has_method("harvest"):
		var resource_node: Node2D = node as Node2D
		var amount: int = 1
		if resource_node.has_method("get_current_amount"):
			amount = resource_node.get_current_amount()
		elif resource_node.get("current_amount") != null:
			amount = int(resource_node.get("current_amount"))
		if amount > 0:
			var dist_sq: float = resource_node.global_position.distance_squared_to(world_pos)
			if dist_sq < best_dist_sq:
				best = resource_node
				best_dist_sq = dist_sq

	for child: Node in node.get_children():
		var candidate: Node2D = _find_resource_recursive(child, world_pos, best, best_dist_sq)
		if candidate != best:
			best = candidate
			best_dist_sq = candidate.global_position.distance_squared_to(world_pos)
	return best


func _build_formation_targets(center: Vector2, unit_count: int) -> Dictionary:
	var targets: Dictionary = {}
	if unit_count <= 1:
		targets[0] = center
		return targets

	var spacing: float = 34.0
	var columns: int = ceili(sqrt(float(unit_count)))
	var rows: int = ceili(float(unit_count) / float(columns))
	var index: int = 0
	for row in range(rows):
		for col in range(columns):
			if index >= unit_count:
				break
			var offset: Vector2 = Vector2(
				(float(col) - float(columns - 1) * 0.5) * spacing,
				(float(row) - float(rows - 1) * 0.5) * spacing
			)
			targets[index] = center + offset
			index += 1
	return targets


## Set the camera reference used for coordinate conversion.
func set_camera(cam: Camera2D) -> void:
	_camera = cam


## Check if the player is currently dragging (has moved beyond click threshold).
func is_dragging() -> bool:
	return _has_dragged


## Check if a selection box is actively being drawn.
func is_selecting() -> bool:
	return _is_selecting


## Get the world-space bounds of the current selection rectangle.
func get_selection_rect_world() -> Rect2:
	var start_world: Vector2 = _press_start_world
	var end_world: Vector2 = _screen_to_world(_current_screen_pos)
	return Rect2(
		Vector2(minf(start_world.x, end_world.x), minf(start_world.y, end_world.y)),
		Vector2(absf(end_world.x - start_world.x), absf(end_world.y - start_world.y))
	)


func _spawn_click_feedback(screen_pos: Vector2) -> void:
	if _camera != null and _camera.has_method("spawn_touch_effect"):
		var world_pos: Vector2 = _screen_to_world(screen_pos)
		_camera.spawn_touch_effect(world_pos)


func _recenter_camera_on_army() -> void:
	if _camera != null and _camera.has_method("recenter_on_army"):
		_camera.recenter_on_army()
