## Manages all selection logic for units and buildings. Handles single clicks,
## additive selection, box/rubber-band selection, double-click select-by-type,
## and control groups 1-9.
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

## Control groups: key (1-9) → Array[int] of unit_ids.
var control_groups: Dictionary = {}

## Double-click detection.
var _last_click_time: float = 0.0
var _last_click_pos: Vector2 = Vector2.ZERO
var _double_click_threshold: float = 0.3  # seconds
var _double_click_max_dist: float = 50.0  # pixels

var _local_player_id: int = -1

# =============================================================================
# Signals
# =============================================================================

signal group_assigned(group_id: int, unit_ids: Array[int])
signal group_recalled(group_id: int, unit_ids: Array[int])
signal double_click_select(unit_type: String, unit_ids: Array[int])

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_connect_event_bus()
	_connect_input_actions()


func _process(_delta: float) -> void:
	pass

# =============================================================================
# Setup
# =============================================================================

func _connect_event_bus() -> void:
	if not EventBus.selection_ended.is_connected(_on_selection_ended):
		EventBus.selection_ended.connect(_on_selection_ended)


func _connect_input_actions() -> void:
	# Group assignment: Ctrl+1-9
	# Group recall: 1-9 (without Ctrl)
	for i in range(1, 10):
		var action_name: String = "group_%d" % i
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event: InputEventKey = InputEventKey.new()
			event.keycode = KEY_1 + i - 1
			event.physical_keycode = KEY_1 + i - 1
			InputMap.action_add_event(action_name, event)


func _unhandled_input(event: InputEvent) -> void:
	# Handle group hotkeys.
	for i in range(1, 10):
		var action_name: String = "group_%d" % i
		if event.is_action_pressed(action_name):
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_COMMAND):
				_assign_group(i)
			else:
				_recall_group(i)
			get_viewport().set_input_as_handled()
			return

# =============================================================================
# Double-Click Handling
# =============================================================================

## Call this from InputManager on left click. Returns true if double-click detected.
func handle_double_click(world_pos: Vector2) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	var time_diff: float = now - _last_click_time
	var dist_diff: float = world_pos.distance_to(_last_click_pos)

	_last_click_time = now
	_last_click_pos = world_pos

	if time_diff < _double_click_threshold and dist_diff < _double_click_max_dist:
		_select_all_of_type_at(world_pos)
		return true

	return false


## Select all units of the same type as the clicked unit.
func _select_all_of_type_at(world_pos: Vector2) -> void:
	var clicked_unit: int = _find_unit_at_position(world_pos)
	if clicked_unit == -1:
		return

	var clicked_node: Node = _find_unit_node(clicked_unit)
	if clicked_node == null:
		return

	var unit_type: String = clicked_node.get("unit_type") if clicked_node.get("unit_type") != null else ""
	if unit_type.is_empty():
		return

	deselect_all()

	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	var found: Array[int] = []

	for unit_node: Node in all_units:
		if found.size() >= max_selection:
			break
		if not unit_node is Node2D:
			continue
		if not _is_own_unit_node(unit_node):
			continue
		var utype: String = unit_node.get("unit_type") if unit_node.get("unit_type") != null else ""
		if utype == unit_type:
			var uid: int = unit_node.get("unit_id") if unit_node.has_method("get") and unit_node.get("unit_id") != null else -1
			if uid != -1 and uid not in found:
				found.append(uid)

	for uid: int in found:
		selected_units.append(uid)
		_set_unit_selected_visual(uid, true)
		EventBus.unit_selected.emit(uid, _get_local_player_id())

	if found.size() > 0:
		_emit_selection_changed()
		double_click_select.emit(unit_type, found)

# =============================================================================
# Control Groups (1-9)
# =============================================================================

## Assign current selection to a control group.
func _assign_group(group_id: int) -> void:
	if selected_units.is_empty():
		# Clear the group if nothing selected.
		control_groups.erase(group_id)
		group_assigned.emit(group_id, [])
		return

	control_groups[group_id] = selected_units.duplicate()
	group_assigned.emit(group_id, control_groups[group_id])


## Recall a control group (select its units).
func _recall_group(group_id: int) -> void:
	if not control_groups.has(group_id):
		return

	var unit_ids: Array[int] = control_groups[group_id]
	# Filter out dead/invalid units.
	var valid_ids: Array[int] = []
	for uid: int in unit_ids:
		var node: Node = _find_unit_node(uid)
		if node != null:
			var hp: int = 0
			var health_comp: Node = node.get_node_or_null("HealthComponent")
			if health_comp != null:
				hp = health_comp.get("current_hp") if health_comp.get("current_hp") != null else 0
			else:
				hp = node.get("current_hp") if node.get("current_hp") != null else 0
			if hp > 0:
				valid_ids.append(uid)

	# Update group with only alive units.
	control_groups[group_id] = valid_ids

	deselect_all()

	for uid: int in valid_ids:
		if uid not in selected_units:
			selected_units.append(uid)
			_set_unit_selected_visual(uid, true)
			EventBus.unit_selected.emit(uid, _get_local_player_id())

	if valid_ids.size() > 0:
		_emit_selection_changed()
		group_recalled.emit(group_id, valid_ids)


## Check if a unit is in any control group.
func get_unit_group(unit_id: int) -> int:
	for group_id: int in control_groups:
		if unit_id in control_groups[group_id]:
			return group_id
	return -1


## Get all control groups.
func get_control_groups() -> Dictionary:
	return control_groups.duplicate(true)


## Clear a specific control group.
func clear_group(group_id: int) -> void:
	control_groups.erase(group_id)


## Clear all control groups.
func clear_all_groups() -> void:
	control_groups.clear()

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


## Get the unit type of the first selected unit.
func get_selection_type() -> String:
	if selected_units.is_empty():
		return ""
	var node: Node = _find_unit_node(selected_units[0])
	if node != null:
		return node.get("unit_type") if node.get("unit_type") != null else ""
	return ""

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

	# Clear box coordinates after selection completes.
	selection_box_start = Vector2.ZERO
	selection_box_end = Vector2.ZERO

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
	# Check for double-click first.
	if handle_double_click(world_pos):
		return

	var clicked_unit: int = _find_unit_at_position(world_pos)
	if clicked_unit != -1:
		select_unit(clicked_unit, shift_held)
		return

	var clicked_building: int = _find_building_at_position(world_pos)
	if clicked_building != -1:
		select_building(clicked_building)
		return

	if not shift_held:
		deselect_all()

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


func _find_unit_node(unit_id: int) -> Node:
	var all_units: Array[Node] = get_tree().get_nodes_in_group("units")
	for unit_node: Node in all_units:
		if unit_node.has_method("get") and unit_node.get("unit_id") != null:
			if int(unit_node.get("unit_id")) == unit_id:
				return unit_node
	return null

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
