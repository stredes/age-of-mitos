## Central command dispatcher. Receives input from SelectionManager/InputManager,
## routes commands to selected units/buildings, handles shift-queueing, and manages
## command queues per unit. Connects to EventBus for UI feedback.
class_name CommandManager
extends Node

signal command_issued(unit_id: int, command: UnitCommand)
signal command_queued(unit_id: int, command: UnitCommand)
signal command_failed(unit_id: int, reason: String)
signal command_cleared(unit_id: int)

var unit_command_queues: Dictionary = {}
const MAX_QUEUE_PER_UNIT: int = 10

func _ready() -> void:
	EventBus.unit_command_requested.connect(_on_unit_command_requested)
	EventBus.building_command_requested.connect(_on_building_command_requested)
	EventBus.selection_cleared.connect(_on_selection_cleared)


func _on_unit_command_requested(command_data: Dictionary) -> void:
	var command_type_str: String = command_data.get("command_type", "")
	var target_data: Dictionary = command_data.get("target", {})
	var shift_held: bool = command_data.get("shift_held", false)

	if command_type_str.is_empty():
		push_warning("CommandManager: Empty command type requested")
		return

	var local_player: int = GameManager.get_local_player_id()
	var selection_manager: Node = get_node_or_null("/root/GameWorld/SelectionManager")
	if selection_manager == null:
		selection_manager = get_node_or_null("/root/GameWorld/World/SelectionManager")
	if selection_manager == null:
		push_warning("CommandManager: SelectionManager not found")
		return

	var selected_units: Array[int] = selection_manager.get_selected_units()
	if selected_units.is_empty():
		AudioManager.play_sfx("res://audio/sfx/cant_do.wav")
		return

	var command: UnitCommand = _build_command_from_data(command_type_str, target_data, shift_held)
	if command == null:
		AudioManager.play_sfx("res://audio/sfx/cant_do.wav")
		return

	_issue_command_to_units(selected_units, command, local_player)


func _on_building_command_requested(command_data: Dictionary) -> void:
	var command_type_str: String = command_data.get("command_type", "")
	var target_data: Dictionary = command_data.get("target", {})
	var shift_held: bool = command_data.get("shift_held", false)

	if command_type_str.is_empty():
		return

	var selection_manager: Node = get_node_or_null("/root/GameWorld/SelectionManager")
	if selection_manager == null:
		selection_manager = get_node_or_null("/root/GameWorld/World/SelectionManager")
	if selection_manager == null:
		return

	var building_id: int = selection_manager.get_selected_building()
	if building_id == -1:
		return

	var local_player: int = GameManager.get_local_player_id()
	var building_manager: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if building_manager == null:
		building_manager = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if building_manager == null or not building_manager.has_method("get_building"):
		return

	var building: Node = building_manager.get_building(building_id)
	if building == null or building.get("player_id") != local_player:
		return

	var command: UnitCommand = _build_building_command(command_type_str, target_data, shift_held)
	if command == null:
		AudioManager.play_sfx("res://audio/sfx/cant_do.wav")
		return

	_issue_building_command(building_id, command)


func _on_selection_cleared() -> void:
	pass


func _build_command_from_data(command_type: String, target: Dictionary, shift_queued: bool) -> UnitCommand:
	match command_type.to_upper():
		"MOVE":
			var pos: Vector2 = target.get("position", Vector2.ZERO)
			return UnitCommand.create_move(pos, 0, shift_queued)
		"ATTACK":
			var target_id: int = target.get("entity_id", -1)
			var target_type: String = target.get("entity_type", "unit")
			if target_id == -1:
				return null
			return UnitCommand.create_attack(target_id, target_type, shift_queued)
		"ATTACK_MOVE":
			var pos: Vector2 = target.get("position", Vector2.ZERO)
			return UnitCommand.create_attack_move(pos, 0, shift_queued)
		"HARVEST":
			var resource_id: int = target.get("resource_id", -1)
			var resource_type: String = target.get("resource_type", "wood")
			if resource_id == -1:
				return null
			return UnitCommand.create_harvest(resource_id, resource_type, shift_queued)
		"BUILD":
			var building_type: String = target.get("building_type", "")
			var cell: Vector2i = target.get("cell", Vector2i.ZERO)
			if building_type.is_empty():
				return null
			return UnitCommand.create_build(building_type, cell, shift_queued)
		"REPAIR":
			var target_id: int = target.get("entity_id", -1)
			var target_type: String = target.get("entity_type", "building")
			if target_id == -1:
				return null
			return UnitCommand.create_repair(target_id, target_type, shift_queued)
		"PATROL":
			var point_a: Vector2 = target.get("point_a", Vector2.ZERO)
			var point_b: Vector2 = target.get("point_b", Vector2.ZERO)
			return UnitCommand.create_patrol(point_a, point_b, shift_queued)
		"FOLLOW":
			var target_id: int = target.get("entity_id", -1)
			var target_type: String = target.get("entity_type", "unit")
			if target_id == -1:
				return null
			return UnitCommand.create_follow(target_id, target_type, shift_queued)
		"HOLD_POSITION":
			return UnitCommand.create_hold_position(shift_queued)
		"STOP":
			return UnitCommand.create_stop(shift_queued)
		"RETURN_RESOURCE":
			var drop_off_id: int = target.get("entity_id", -1)
			var drop_off_type: String = target.get("entity_type", "building")
			if drop_off_id == -1:
				return null
			return UnitCommand.create_return_resource(drop_off_id, drop_off_type, shift_queued)
		"GARRISON":
			var building_id: int = target.get("entity_id", -1)
			if building_id == -1:
				return null
			return UnitCommand.create_garrison(building_id, shift_queued)
		"UNGARRISON":
			var exit_pos: Vector2 = target.get("position", Vector2.ZERO)
			return UnitCommand.create_ungarrison(exit_pos, shift_queued)
		_:
			push_warning("CommandManager: Unknown command type '%s'" % command_type)
			return null


func _build_building_command(command_type: String, target: Dictionary, shift_queued: bool) -> UnitCommand:
	match command_type.to_upper():
		"TRAIN":
			var unit_type: String = target.get("unit_type", "")
			if unit_type.is_empty():
				return null
			var cmd = UnitCommand.new()
			cmd.command_type = UnitCommand.CommandType.MOVE
			cmd.target_entity_type = unit_type
			cmd.data["train_unit"] = unit_type
			cmd.shift_queued = shift_queued
			return cmd
		"STOP":
			return UnitCommand.create_stop(shift_queued)
		"CANCEL_PRODUCTION":
			var cmd = UnitCommand.new()
			cmd.command_type = UnitCommand.CommandType.STOP
			cmd.data["cancel_production"] = true
			cmd.shift_queued = shift_queued
			return cmd
		_:
			return null


func _issue_command_to_units(unit_ids: Array[int], command: UnitCommand, player_id: int) -> void:
	var unit_manager: Node = get_node_or_null("/root/GameWorld/UnitManager")
	if unit_manager == null:
		unit_manager = get_node_or_null("/root/GameWorld/World/UnitManager")
	if unit_manager == null:
		push_warning("CommandManager: UnitManager not found")
		return

	var formation_targets: Dictionary = _build_formation_targets(command.target_position, unit_ids.size())

	for i in range(unit_ids.size()):
		var unit_id: int = unit_ids[i]
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null or unit.get("player_id") != player_id:
			continue

		var unit_command: UnitCommand = command.duplicate(true)
		if unit_command.command_type in [UnitCommand.CommandType.MOVE, UnitCommand.CommandType.ATTACK_MOVE]:
			if formation_targets.has(i):
				unit_command.target_position = formation_targets[i]
			unit_command.formation_index = i

		_process_unit_command(unit, unit_command)


func _issue_building_command(building_id: int, command: UnitCommand) -> void:
	var building_manager: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if building_manager == null:
		building_manager = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if building_manager == null or not building_manager.has_method("get_building"):
		return

	var building: Node = building_manager.get_building(building_id)
	if building == null:
		return

	if command.data.has("train_unit"):
		var unit_type: String = command.data["train_unit"]
		var unit_data: Dictionary = DataManager.get_unit_data(unit_type)
		if unit_data.is_empty():
			AudioManager.play_sfx("res://audio/sfx/cant_do.wav")
			return
		var cost: Dictionary = unit_data.get("cost", {})
		if not GameManager.spend_resources(cost, GameManager.get_local_player_id()):
			EventBus.button_pressed.emit("cant_afford", GameManager.get_local_player_id())
			AudioManager.play_sfx("res://audio/sfx/cant_do.wav")
			return
		if building.has_method("start_production"):
			building.start_production(unit_type)
			AudioManager.play_sfx("res://audio/sfx/ui_click.wav")
		return

	if command.data.has("cancel_production"):
		if building.has_method("cancel_production"):
			building.cancel_production()
			AudioManager.play_sfx("res://audio/sfx/ui_click.wav")
		return


func _process_unit_command(unit: Node2D, command: UnitCommand) -> void:
	if command.shift_queued:
		_queue_command(unit, command)
		command_queued.emit(unit.get("unit_id"), command)
		AudioManager.play_sfx("res://audio/sfx/ui_click.wav")
		return

	_clear_command_queue(unit)

	var state_machine: Node = unit.get_node_or_null("UnitStateMachine")
	if state_machine == null:
		command_failed.emit(unit.get("unit_id"), "No state machine")
		return

	var success: bool = false

	match command.command_type:
		UnitCommand.CommandType.MOVE:
			success = _execute_move_command(unit, command, state_machine)
		UnitCommand.CommandType.ATTACK:
			success = _execute_attack_command(unit, command, state_machine)
		UnitCommand.CommandType.ATTACK_MOVE:
			success = _execute_attack_move_command(unit, command, state_machine)
		UnitCommand.CommandType.HARVEST:
			success = _execute_harvest_command(unit, command, state_machine)
		UnitCommand.CommandType.BUILD:
			success = _execute_build_command(unit, command, state_machine)
		UnitCommand.CommandType.REPAIR:
			success = _execute_repair_command(unit, command, state_machine)
		UnitCommand.CommandType.PATROL:
			success = _execute_patrol_command(unit, command, state_machine)
		UnitCommand.CommandType.FOLLOW:
			success = _execute_follow_command(unit, command, state_machine)
		UnitCommand.CommandType.HOLD_POSITION:
			success = _execute_hold_position_command(unit, command, state_machine)
		UnitCommand.CommandType.STOP:
			success = _execute_stop_command(unit, state_machine)
		UnitCommand.CommandType.RETURN_RESOURCE:
			success = _execute_return_resource_command(unit, command, state_machine)
		UnitCommand.CommandType.GARRISON:
			success = _execute_garrison_command(unit, command, state_machine)
		UnitCommand.CommandType.UNGARRISON:
			success = _execute_ungarrison_command(unit, command, state_machine)
		_:
			command_failed.emit(unit.get("unit_id"), "Unknown command type")

	if success:
		command_issued.emit(unit.get("unit_id"), command)
		AudioManager.play_sfx("res://audio/sfx/ui_click.wav")
	else:
		command_failed.emit(unit.get("unit_id"), "Command execution failed")


func _execute_move_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	if state_machine.has_method("change_state"):
		var move_state: Node = state_machine.get_node_or_null("MoveState")
		if move_state != null and move_state.has_method("set_target"):
			move_state.set_target(command.target_position)
		state_machine.change_state("MoveState")
		return true
	return false


func _execute_attack_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var target_id: int = command.target_entity_id
	var target_type: String = command.target_entity_type
	var target: Node2D = _find_entity(target_id, target_type)
	if target == null:
		return false

	if state_machine.has_method("change_state"):
		var combat_comp: Node = unit.get_node_or_null("CombatComponent")
		if combat_comp != null and combat_comp.has_method("set_target"):
			combat_comp.set_target(target)
		state_machine.change_state("AttackState")
		return true
	return false


func _execute_attack_move_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	if state_machine.has_method("change_state"):
		var move_state: Node = state_machine.get_node_or_null("AttackMoveState")
		if move_state != null and move_state.has_method("set_target"):
			move_state.set_target(command.target_position)
		state_machine.change_state("AttackMoveState")
		return true
	return false


func _execute_harvest_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var resource_id: int = command.target_entity_id
	var target: Node2D = _find_entity(resource_id, "resource")
	if target == null:
		return false

	unit.set("pending_target_resource", target)
	if state_machine.has_method("change_state"):
		state_machine.change_state("HarvestState")
		return true
	return false


func _execute_build_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var building_type: String = command.target_entity_type
	var cell: Vector2i = command.data.get("cell", Vector2i.ZERO)

	if unit.get("unit_type") != "villager":
		return false

	var grid_manager: Node = get_node_or_null("/root/GameWorld/GridManager")
	if grid_manager == null:
		grid_manager = get_node_or_null("/root/GameWorld/World/GridManager")
	if grid_manager == null:
		return false

	if not grid_manager.is_buildable(cell, Vector2i(2, 2)):
		return false

	var building_manager: Node = get_node_or_null("/root/GameWorld/BuildingManager")
	if building_manager == null:
		building_manager = get_node_or_null("/root/GameWorld/World/BuildingManager")
	if building_manager == null or not building_manager.has_method("place_building"):
		return false

	var building_node: Node2D = building_manager.place_building(building_type, cell, unit.get("player_id"))
	if building_node == null:
		return false

	unit.set("pending_target_building", building_node)
	if state_machine.has_method("change_state"):
		state_machine.change_state("BuildState")
		return true
	return false


func _execute_repair_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var target_id: int = command.target_entity_id
	var target_type: String = command.target_entity_type
	var target: Node2D = _find_entity(target_id, target_type)
	if target == null:
		return false

	if unit.get("unit_type") != "villager":
		return false

	var health_comp: Node = target.get_node_or_null("HealthComponent")
	if health_comp == null or not health_comp.has_method("get_current_hp"):
		return false

	var current_hp: int = health_comp.get_current_hp()
	var max_hp: int = health_comp.get_max_hp()
	if current_hp >= max_hp:
		return false

	unit.set("pending_target_building", target)
	if state_machine.has_method("change_state"):
		state_machine.change_state("RepairState")
		return true
	return false


func _execute_patrol_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var point_a: Vector2 = command.data.get("patrol_point_a", Vector2.ZERO)
	var point_b: Vector2 = command.data.get("patrol_point_b", Vector2.ZERO)

	if point_a == Vector2.ZERO or point_b == Vector2.ZERO:
		return false

	if state_machine.has_method("change_state"):
		var patrol_state: Node = state_machine.get_node_or_null("PatrolState")
		if patrol_state != null:
			if patrol_state.has_method("set_patrol_points"):
				patrol_state.set_patrol_points(point_a, point_b)
		state_machine.change_state("PatrolState")
		return true
	return false


func _execute_follow_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var target_id: int = command.target_entity_id
	var target_type: String = command.target_entity_type
	var target: Node2D = _find_entity(target_id, target_type)
	if target == null:
		return false

	if state_machine.has_method("change_state"):
		var follow_state: Node = state_machine.get_node_or_null("FollowState")
		if follow_state != null and follow_state.has_method("set_target"):
			follow_state.set_target(target)
		state_machine.change_state("FollowState")
		return true
	return false


func _execute_hold_position_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var movement: Node = unit.get_node_or_null("MovementComponent")
	if movement != null and movement.has_method("stop"):
		movement.stop()

	if state_machine.has_method("change_state"):
		var hold_state: Node = state_machine.get_node_or_null("HoldPositionState")
		if hold_state != null:
			if hold_state.has_method("set_hold_position"):
				hold_state.set_hold_position(unit.global_position)
		state_machine.change_state("HoldPositionState")
		return true
	return false


func _execute_stop_command(unit: Node2D, state_machine: Node) -> bool:
	var movement: Node = unit.get_node_or_null("MovementComponent")
	if movement != null and movement.has_method("stop"):
		movement.stop()

	unit.set("pending_move_position", Vector2.ZERO)
	unit.set("pending_target_resource", null)
	unit.set("pending_target_building", null)

	if state_machine.has_method("change_state"):
		state_machine.change_state("IdleState")
		return true
	return false


func _execute_return_resource_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var drop_off_id: int = command.target_entity_id
	var drop_off_type: String = command.target_entity_type
	var drop_off: Node2D = _find_entity(drop_off_id, drop_off_type)
	if drop_off == null:
		return false

	unit.set("pending_target_building", drop_off)
	if state_machine.has_method("change_state"):
		var return_state: Node = state_machine.get_node_or_null("ReturnResourceState")
		if return_state != null and return_state.has_method("set_drop_off"):
			return_state.set_drop_off(drop_off)
		state_machine.change_state("ReturnResourceState")
		return true
	return false


func _execute_garrison_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var building_id: int = command.target_entity_id
	var building: Node2D = _find_entity(building_id, "building")
	if building == null:
		return false

	if building.has_method("try_garrison"):
		if building.try_garrison(unit):
			if state_machine.has_method("change_state"):
				state_machine.change_state("IdleState")
			return true
	return false


func _execute_ungarrison_command(unit: Node2D, command: UnitCommand, state_machine: Node) -> bool:
	var exit_pos: Vector2 = command.target_position
	if exit_pos == Vector2.ZERO:
		exit_pos = unit.global_position + Vector2(32, 0)

	if state_machine.has_method("change_state"):
		var move_state: Node = state_machine.get_node_or_null("MoveState")
		if move_state != null and move_state.has_method("set_target"):
			move_state.set_target(exit_pos)
		state_machine.change_state("MoveState")
		return true
	return false


func _queue_command(unit: Node2D, command: UnitCommand) -> void:
	var unit_id: int = unit.get("unit_id")
	if not unit_command_queues.has(unit_id):
		unit_command_queues[unit_id] = []

	var queue: Array = unit_command_queues[unit_id]
	if queue.size() >= MAX_QUEUE_PER_UNIT:
		return

	queue.append(command.duplicate(true))


func _clear_command_queue(unit: Node2D) -> void:
	var unit_id: int = unit.get("unit_id")
	if unit_command_queues.has(unit_id):
		unit_command_queues[unit_id].clear()
		command_cleared.emit(unit_id)


func _find_entity(entity_id: int, entity_type: String) -> Node2D:
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root

	var groups: Array[String] = []
	match entity_type:
		"unit": groups = ["units"]
		"building": groups = ["buildings"]
		"resource": groups = ["resources", "resource_nodes"]
		_: groups = ["units"]

	for group_name: String in groups:
		var entities: Array[Node] = get_tree().get_nodes_in_group(group_name)
		for entity: Node in entities:
			if entity is Node2D:
				var eid: int = entity.get("unit_id") if entity.get("unit_id") != null else entity.get("building_id") if entity.get("building_id") != null else entity.get("resource_id") if entity.get("resource_id") != null else -1
				if eid == entity_id:
					return entity as Node2D
	return null


func _build_formation_targets(center: Vector2, count: int) -> Dictionary:
	var targets: Dictionary = {}
	if count <= 1:
		targets[0] = center
		return targets

	var spacing: float = 34.0
	var columns: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(columns))
	var index: int = 0
	for row in range(rows):
		for col in range(columns):
			if index >= count:
				break
			var offset: Vector2 = Vector2(
				(float(col) - float(columns - 1) * 0.5) * spacing,
				(float(row) - float(rows - 1) * 0.5) * spacing
			)
			targets[index] = center + offset
			index += 1
	return targets


func get_queued_commands(unit_id: int) -> Array[UnitCommand]:
	if unit_command_queues.has(unit_id):
		return unit_command_queues[unit_id].duplicate()
	return []


func get_next_queued_command(unit_id: int) -> UnitCommand:
	if unit_command_queues.has(unit_id) and unit_command_queues[unit_id].size() > 0:
		return unit_command_queues[unit_id].pop_front()
	return null


func has_queued_commands(unit_id: int) -> bool:
	return unit_command_queues.has(unit_id) and unit_command_queues[unit_id].size() > 0