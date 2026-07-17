## Manages all selection logic for units and buildings. Handles single clicks,
## additive selection, box/rubber-band selection, and emits selection state changes.
class_name SelectionManager
extends Node

# =============================================================================
# Properties
# =============================================================================

var selected_units: Array[int] = []
var selected_building: int = -1
var selection_box_start: Vector2 = Vector2.ZERO
var selection_box_end: Vector2 = Vector2.ZERO
var is_box_selecting: bool = false
var max_selection: int = 50

## Control groups: index 0-8 maps to keys 1-9.
## Each group stores an array of unit IDs.
var control_groups: Array[Array] = [[], [], [], [], [], [], [], [], []]

## Timestamp (seconds) of the last click, used for double-click detection.
var _last_click_time: float = 0.0
## World position of the last click, for double-click proximity check.
var _last_click_pos: Vector2 = Vector2.ZERO
## Maximum time gap (seconds) between clicks to count as double-click.
var _double_click_max_interval: float = 0.35
## Maximum distance (world units) between clicks to count as double-click.
var _double_click_max_distance: float = 40.0

var _local_player_id: int = -1

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_event_bus()


func _process(_delta: float) -> void:
	pass

# =============================================================================
# Setup
# =============================================================================

func _connect_event_bus() -> void:
	if not EventBus.selection_ended.is_connected(_on_selection_ended):
		EventBus.selection_ended.connect(_on_selection_ended)


func _get_local_player_id() -> int:
	if _local_player_id == -1:
		_local_player_id = GameManager.get_local_player_id()
	return _local_player_id

# =============================================================================
# Single Unit Selection
# =============================================================================

func select_unit(unit_id: int, additive: bool = false) -> void:
	if not additive:
		deselect_all()

	if unit_id in selected_units:
		deselect_unit(unit_id)
		return

	if selected_units.size() >= max_selection:
		return

	if not _is_own_unit(unit_id):
		return

	selected_units.append(unit_id)
	_set_unit_selected_visual(unit_id, true)
	EventBus.unit_selected.emit(unit_id, _get_local_player_id())
	_emit_selection_changed()


func deselect_unit(unit_id: int) -> void:
	if unit_id not in selected_units:
		return
	selected_units.erase(unit_id)
	_set_unit_selected_visual(unit_id, false)
	EventBus.unit_deselected.emit(unit_id, _get_local_player_id())
	_emit_selection_changed()

# =============================================================================
# Multi Unit Selection
# =============================================================================

func select_units(unit_ids: Array, additive: bool = false) -> void:
	if not additive:
		deselect_all()

	var added: Array[int] = []
	for id_variant: Variant in unit_ids:
		var uid: int = id_variant if id_variant is int else int(id_variant)
		if uid in selected_units:
			continue
		if selected_units.size() + added.size() >= max_selection:
			break
		if _is_own_unit(uid):
			added.append(uid)

	for uid: int in added:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if added.size() > 0:
		_emit_selection_changed()

# =============================================================================
# Building Selection
# =============================================================================

func select_building(building_id: int) -> void:
	deselect_all()
	selected_building = building_id
	_set_building_selected_visual(building_id, true)
	EventBus.building_selected.emit(building_id, _get_local_player_id())
	_emit_selection_changed()

# =============================================================================
# Deselect
# =============================================================================

func deselect_all() -> void:
	var changed: bool = false
	for uid: int in selected_units:
		_set_unit_selected_visual(uid, false)
		EventBus.unit_deselected.emit(uid, _get_local_player_id())
		changed = true
	selected_units.clear()

	if selected_building != -1:
		_set_building_selected_visual(selected_building, false)
		selected_building = -1
		changed = true

	if changed:
		_emit_selection_changed()

# =============================================================================
# Query
# =============================================================================

func is_unit_selected(unit_id: int) -> bool:
	return unit_id in selected_units


func get_selected_units() -> Array[int]:
	return selected_units.duplicate()


func get_selected_building() -> int:
	return selected_building


func get_selection_count() -> int:
	return selected_units.size() + (1 if selected_building != -1 else 0)


func has_selection() -> bool:
	return selected_units.size() > 0 or selected_building != -1

# =============================================================================
# Control Groups
# =============================================================================

## Assign the current selection to a control group (0-8 → keys 1-9).
func assign_control_group(group_index: int) -> void:
	if group_index < 0 or group_index > 8:
		return
	control_groups[group_index] = selected_units.duplicate()


## Recall a control group — select all units stored in it.
func recall_control_group(group_index: int) -> void:
	if group_index < 0 or group_index > 8:
		return
	var group_units: Array = control_groups[group_index]
	if group_units.is_empty():
		return

	deselect_all()
	var added: Array[int] = []
	for id_variant: Variant in group_units:
		var uid: int = id_variant if id_variant is int else int(id_variant)
		if uid in added:
			continue
		if added.size() >= max_selection:
			break
		if _is_own_unit(uid):
			added.append(uid)

	for uid: int in added:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if added.size() > 0:
		_emit_selection_changed()

# =============================================================================
# Box Selection
# =============================================================================

func start_box_selection(world_pos: Vector2) -> void:
	is_box_selecting = true
	selection_box_start = world_pos
	selection_box_end = world_pos


func update_box_selection(world_pos: Vector2) -> void:
	if not is_box_selecting:
		return
	selection_box_end = world_pos


func end_box_selection(world_pos: Vector2) -> Array[int]:
	if not is_box_selecting:
		return []
	is_box_selecting = false
	selection_box_end = world_pos

	var rect: Rect2 = get_selection_box()
	var found: Array[int] = select_all_in_rect(rect)
	return found


func get_selection_box() -> Rect2:
	var top_left: Vector2 = Vector2(
		minf(selection_box_start.x, selection_box_end.x),
		minf(selection_box_start.y, selection_box_end.y)
	)
	var size: Vector2 = Vector2(
		absf(selection_box_end.x - selection_box_start.x),
		absf(selection_box_end.y - selection_box_start.y)
	)
	return Rect2(top_left, size)

# =============================================================================
# Rect Selection
# =============================================================================

func select_all_in_rect(rect: Rect2) -> Array[int]:
	if rect.size.length() < 1.0:
		return []

	deselect_all()

	var found_units: Array[int] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit_node: Node in all_units:
		if found_units.size() >= max_selection:
			break
		if not unit_node is Node2D:
			continue
		if not _is_own_unit_node(unit_node):
			continue
		var unit_pos: Vector2 = (unit_node as Node2D).global_position
		if rect.has_point(unit_pos):
			var uid: int = unit_node.get("unit_id") if unit_node.has_method("get") and unit_node.get("unit_id") != null else -1
			if uid != -1 and uid not in found_units:
				found_units.append(uid)

	for uid: int in found_units:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if found_units.size() > 0:
		_emit_selection_changed()

	return found_units

# =============================================================================
# Input Integration
# =============================================================================

func handle_click_at(world_pos: Vector2, shift_held: bool) -> void:
	var clicked_unit: int = _find_unit_at_position(world_pos)
	if clicked_unit != -1:
		select_unit(clicked_unit, shift_held)
		_check_double_click(clicked_unit)
		return

	var clicked_building: int = _find_building_at_position(world_pos)
	if clicked_building != -1:
		select_building(clicked_building)
		_last_click_time = Time.get_ticks_msec() / 1000.0
		_last_click_pos = world_pos
		return

	if not shift_held:
		deselect_all()

	_last_click_time = Time.get_ticks_msec() / 1000.0
	_last_click_pos = world_pos


## Detect double-click and select all visible units of the same type.
func _check_double_click(unit_id: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0

	# Not a double-click if too slow or too far apart.
	var click_pos: Vector2 = _get_unit_position(unit_id)
	if now - _last_click_time > _double_click_max_interval:
		_last_click_time = now
		_last_click_pos = click_pos
		return
	if _last_click_pos.distance_to(click_pos) > _double_click_max_distance:
		_last_click_time = now
		_last_click_pos = click_pos
		return

	# Double-click detected — select all own visible units of the same type.
	var target_type: String = _get_unit_type(unit_id)
	if target_type.is_empty():
		_last_click_time = now
		_last_click_pos = click_pos
		return

	select_all_of_type(target_type)
	_last_click_time = 0.0
	_last_click_pos = click_pos


## Select all visible own units of the given type.
func select_all_of_type(unit_type: String) -> void:
	deselect_all()
	var found: Array[int] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit_node: Node in all_units:
		if found.size() >= max_selection:
			break
		if not unit_node is Node2D:
			continue
		if not _is_own_unit_node(unit_node):
			continue
		var utype: String = _get_unit_type_from_node(unit_node)
		if utype == unit_type:
			var uid: int = _get_unit_id_from_node(unit_node)
			if uid != -1:
				found.append(uid)

	for uid: int in found:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if found.size() > 0:
		_emit_selection_changed()


## Select all idle villager units owned by the local player.
func select_idle_villagers() -> void:
	deselect_all()
	var found: Array[int] = []
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")

	for unit_node: Node in all_units:
		if found.size() >= max_selection:
			break
		if not unit_node is Node2D:
			continue
		if not _is_own_unit_node(unit_node):
			continue
		var utype: String = _get_unit_type_from_node(unit_node)
		if utype != "villager":
			continue
		# Check if the unit's state machine is in IdleState.
		var state_machine: Node = unit_node.get_node_or_null("UnitStateMachine")
		if state_machine != null:
			var current_state: String = ""
			if state_machine.has_method("get"):
				var state_node: Node = state_machine.get("current_state")
				if state_node != null and state_node is Node:
					current_state = state_node.name
			if current_state != "IdleState":
				continue
		else:
			# If no state machine, check if the unit has a state property.
			var unit_state: String = ""
			if unit_node.has_method("get") and unit_node.get("current_state") != null:
				unit_state = str(unit_node.get("current_state"))
			if not unit_state.is_empty() and unit_state != "idle":
				continue

		var uid: int = _get_unit_id_from_node(unit_node)
		if uid != -1:
			found.append(uid)

	for uid: int in found:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if found.size() > 0:
		_emit_selection_changed()

# =============================================================================
# Entity Detection
# =============================================================================

func _find_unit_at_position(world_pos: Vector2) -> int:
	var click_radius: float = 24.0
	var best_id: int = -1
	var best_dist_sq: float = click_radius * click_radius

	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if not unit_node is Node2D:
			continue
		if not _is_own_unit_node(unit_node):
			continue
		var dist_sq: float = (unit_node as Node2D).global_position.distance_squared_to(world_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = unit_node.get("unit_id") if unit_node.has_method("get") and unit_node.get("unit_id") != null else -1

	return best_id


func _find_building_at_position(world_pos: Vector2) -> int:
	var click_radius: float = 48.0
	var best_id: int = -1
	var best_dist_sq: float = click_radius * click_radius

	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null:
		return -1

	if not bm.has_method("get"):
		return -1

	var buildings_dict: Dictionary = bm.get("buildings") if bm.get("buildings") != null else {}
	for id_variant: Variant in buildings_dict:
		var bid: int = id_variant if id_variant is int else int(id_variant)
		var node: Node2D = buildings_dict[id_variant]
		if not is_instance_valid(node):
			continue
		var dist_sq: float = node.global_position.distance_squared_to(world_pos)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = bid

	return best_id

# =============================================================================
# Ownership
# =============================================================================

func _is_own_unit(unit_id: int) -> bool:
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if unit_node.has_method("get") and unit_node.get("unit_id") == unit_id:
			return _is_own_unit_node(unit_node)
	return false


func _is_own_unit_node(unit_node: Node) -> bool:
	if unit_node.has_method("get") and unit_node.get("player_id") != null:
		return unit_node.get("player_id") == _get_local_player_id()
	return false


func _set_unit_selected_visual(unit_id: int, selected: bool) -> void:
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if unit_node.get("unit_id") == null or int(unit_node.get("unit_id")) != unit_id:
			continue
		unit_node.set("is_selected", selected)
		if unit_node.has_method("queue_redraw"):
			unit_node.queue_redraw()
		var selection_component: Node = unit_node.get_node_or_null("SelectionComponent")
		if selection_component != null:
			selection_component.set("is_selected", selected)
		return


func _set_building_selected_visual(building_id: int, selected: bool) -> void:
	var bm: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if bm == null:
		bm = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if bm == null or not bm.has_method("get_building"):
		return
	var building: Node = bm.get_building(building_id)
	if building == null:
		return
	if selected and building.has_method("select"):
		building.select()
	elif not selected and building.has_method("deselect"):
		building.deselect()
	else:
		building.set("is_selected", selected)
		if building.has_method("queue_redraw"):
			building.queue_redraw()

# =============================================================================
# Signal Emission
# =============================================================================

func _emit_selection_changed() -> void:
	var building_arr: Array = []
	if selected_building != -1:
		building_arr.append(selected_building)
	EventBus.selection_changed.emit(selected_units, building_arr)

# =============================================================================
# Event Bus Handlers
# =============================================================================

func _on_selection_ended(start_pos: Vector2, end_pos: Vector2, _selected_ids: Array) -> void:
	var rect: Rect2 = Rect2(
		Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y)),
		Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	)

	if rect.size.length() > 5.0:
		var found: Array[int] = select_all_in_rect(rect)
		if found.is_empty():
			deselect_all()

# =============================================================================
# Helper Methods
# =============================================================================

func _get_unit_position(unit_id: int) -> Vector2:
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if unit_node is Node2D and unit_node.has_method("get") and unit_node.get("unit_id") == unit_id:
			return (unit_node as Node2D).global_position
	return Vector2.ZERO


func _get_unit_type(unit_id: int) -> String:
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if unit_node.has_method("get") and unit_node.get("unit_id") == unit_id:
			return _get_unit_type_from_node(unit_node)
	return ""


func _get_unit_type_from_node(unit_node: Node) -> String:
	if unit_node.has_method("get") and unit_node.get("unit_type") != null:
		return str(unit_node.get("unit_type"))
	return ""


func _get_unit_id_from_node(unit_node: Node) -> int:
	if unit_node.has_method("get") and unit_node.get("unit_id") != null:
		return int(unit_node.get("unit_id"))
	return -1
