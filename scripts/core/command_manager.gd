class_name CommandManager
extends Node

signal command_issued(command: UnitCommand, recipients: Array[UnitBase])
signal command_queued(command: UnitCommand, recipient: UnitBase)
signal command_cancelled(unit: UnitBase)
signal all_commands_cleared()

var _command_queues: Dictionary[int, Array[UnitCommand]] = {}
var _command_history: Array[Dictionary] = []
var _max_history: int = 100
var _command_id_counter: int = 0
var _selected_units: Array[UnitBase] = []
var _selection_manager: SelectionManager = null
var _event_bus: EventBus = null
var _game_world: Node = null

func _ready() -> void:
	_event_bus = EventBus
	_game_world = get_node_or_null("/root/GameWorld")
	_selection_manager = _find_selection_manager()
	
	if _selection_manager != null:
		_event_bus.selection_changed.connect(_on_selection_changed)
	
	_event_bus.button_pressed.connect(_on_button_pressed)
	
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_ended.connect(_on_game_ended)

func _find_selection_manager() -> Node:
	var sm = get_node_or_null("/root/GameWorld/SelectionManager")
	if sm != null:
		return sm
	return get_node_or_null("/root/GameWorld/World/SelectionManager")

func _on_game_started() -> void:
	_command_queues.clear()
	_command_history.clear()
	_command_id_counter = 0

func _on_game_ended() -> void:
	clear_all_commands()

func _on_selection_changed(selected_unit_ids: Array, selected_building_ids: Array) -> void:
	_selected_units = _get_units_from_ids(selected_unit_ids)

func _get_units_from_ids(ids: Array[int]) -> Array[UnitBase]:
	var units = []
	for id in ids:
		var unit = _find_unit_by_id(id)
		if unit != null and unit is UnitBase:
			units.append(unit)
	return units

func _find_unit_by_id(unit_id: int) -> Node2D:
	if _game_world != null and _game_world.has_method("get_unit_by_id"):
		return _game_world.get_unit_by_id(unit_id)
	return null

func _on_button_pressed(button_name: String, player_id: int) -> void:
	if _selected_units.is_empty():
		return
	
	match button_name:
		"stop_command":
			issue_command(UnitCommand.stop(false, player_id), _selected_units)
		"build_menu":
			EventBus.menu_opened.emit("build_menu")
		"gather_wood", "gather_food", "gather_stone", "gather_gold":
			var resource_type = button_name.replace("gather_", "")
			_handle_gather_command(resource_type, player_id)
		"train_villager", "train_swordsman", "train_spearman", "train_archer", "train_cavalry":
			var unit_type = button_name.replace("train_", "")
			issue_command(UnitCommand.train(unit_type, player_id), _selected_units)

func _handle_gather_command(resource_type: String, player_id: int) -> void:
	var target_resource = _find_nearest_resource(resource_type)
	if target_resource != null:
		issue_command(UnitCommand.harvest(target_resource.get_instance_id(), resource_type, false, player_id), _selected_units)
	else:
		var ref_pos = Vector2.ZERO
		if _selected_units.size() > 0:
			ref_pos = _selected_units[0].global_position
		elif _game_world != null:
			ref_pos = _game_world.global_position
		AudioManager.play_sfx("error", ref_pos)

func _find_nearest_resource(resource_type: String) -> Node2D:
	var resources = []
	if _game_world != null and _game_world.has_method("get_resource_nodes"):
		resources = _game_world.get_resource_nodes()
	
	var nearest = null
	var min_dist = INF
	
	# Use first selected unit's position as reference
	var ref_pos = Vector2.ZERO
	if _selected_units.size() > 0:
		ref_pos = _selected_units[0].global_position
	elif _game_world != null:
		ref_pos = _game_world.global_position
	
	for res in resources:
		if res.resource_type == resource_type:
			var dist = ref_pos.distance_to(res.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = res
	return nearest

func _get_issuer_id() -> int:
	var local_player = GameManager.get_local_player_id()
	return local_player if local_player != -1 else 0

func issue_command(command: UnitCommand, recipients: Array[UnitBase] = []) -> void:
	var targets = recipients if not recipients.is_empty() else _selected_units
	if targets.is_empty():
		return
	
	for unit in targets:
		if not is_instance_valid(unit):
			continue
		
		var unit_id = unit.get_instance_id()
		if not _command_queues.has(unit_id):
			_command_queues[unit_id] = []
		
		if command.queued:
			_command_queues[unit_id].append(command)
			_command_queued.emit(command, unit)
		else:
			clear_unit_commands(unit)
			_command_queues[unit_id].append(command)
		
		unit.receive_command(command)
	
	_record_command(command, targets)
	_command_issued.emit(command, targets)

func _record_command(command: UnitCommand, recipients: Array[UnitBase]) -> void:
	var record = {
		"id": _command_id_counter,
		"command": command.to_dict(),
		"recipients": recipients.map(func(u): return u.get_instance_id()),
		"time": Time.get_ticks_msec() / 1000.0
	}
	_command_id_counter += 1
	
	_command_history.append(record)
	if _command_history.size() > _max_history:
		_command_history.pop_front()

func clear_unit_commands(unit: UnitBase) -> void:
	var unit_id = unit.get_instance_id()
	if _command_queues.has(unit_id):
		_command_queues[unit_id].clear()
		unit.clear_command_queue()

func clear_selected_commands() -> void:
	for unit in _selected_units:
		clear_unit_commands(unit)

func clear_all_commands() -> void:
	for unit_id in _command_queues:
		_command_queues[unit_id].clear()
	_command_queues.clear()
	_all_commands_cleared.emit()

func get_unit_queue(unit: UnitBase) -> Array[UnitCommand]:
	var unit_id = unit.get_instance_id()
	return _command_queues.get(unit_id, []).duplicate()

func get_selected_units() -> Array[UnitBase]:
	return _selected_units.duplicate()

func get_command_history() -> Array[Dictionary]:
	return _command_history.duplicate()

func get_current_command(unit: UnitBase) -> UnitCommand:
	var queue = get_unit_queue(unit)
	return queue[0] if not queue.is_empty() else null

func get_queued_commands(unit: UnitBase) -> Array[UnitCommand]:
	var queue = get_unit_queue(unit)
	if queue.size() > 1:
		return queue.slice(1).duplicate()
	return []

func has_queued_commands(unit: UnitBase) -> bool:
	return get_unit_queue(unit).size() > 1

func remove_command_at_index(unit: UnitBase, index: int) -> bool:
	var unit_id = unit.get_instance_id()
	if not _command_queues.has(unit_id) or index < 0 or index >= _command_queues[unit_id].size():
		return false
	
	var removed = _command_queues[unit_id].remove_at(index)
	if index == 0 and is_instance_valid(unit):
		unit.clear_command_queue()
		if not _command_queues[unit_id].is_empty():
			unit.receive_command(_command_queues[unit_id][0])
	return true

func move_command_up(unit: UnitBase, index: int) -> bool:
	var unit_id = unit.get_instance_id()
	if not _command_queues.has(unit_id) or index <= 0 or index >= _command_queues[unit_id].size():
		return false
	
	var queue = _command_queues[unit_id]
	queue.swap(index, index - 1)
	if index == 1 and is_instance_valid(unit):
		unit.receive_command(queue[0])
	return true

func move_command_down(unit: UnitBase, index: int) -> bool:
	var unit_id = unit.get_instance_id()
	if not _command_queues.has(unit_id) or index < 0 or index >= _command_queues[unit_id].size() - 1:
		return false
	
	var queue = _command_queues[unit_id]
	queue.swap(index, index + 1)
	if index == 0 and is_instance_valid(unit):
		unit.receive_command(queue[0])
	return true

func on_unit_removed(unit: UnitBase) -> void:
	var unit_id = unit.get_instance_id()
	if _command_queues.has(unit_id):
		_command_queues.erase(unit_id)

func get_queued_count(unit: UnitBase) -> int:
	return max(0, get_unit_queue(unit).size() - 1)

func get_total_command_count() -> int:
	var count = 0
	for queue in _command_queues.values():
		count += queue.size()
	return count