## Centralized command dispatcher. Listens to EventBus.button_pressed and
## translates high-level commands into concrete unit state changes.
##
## Emits `unit_command` so other systems (UI, audio, particles) can react
## without coupling to the command internals.
class_name CommandManager
extends Node

# =============================================================================
# Signals
# =============================================================================

## Emitted after every successful command. Listeners can use this for
## audio, particles, or UI feedback without referencing CommandManager.
signal unit_command(command: String, unit_ids: Array, data: Dictionary)

## Emitted when a command fails with a reason (e.g. "cant_afford", "invalid_target").
signal command_failed(reason: String, details: Dictionary)

# =============================================================================
# Constants
# =============================================================================

enum Cmd {
	STOP,
	HOLD,
	ATTACK_MOVE,
	PATROL,
	REPAIR,
	GATHER,
	RETURN_RESOURCE,
	MOVE,
	ATTACK,
}

## Human-readable names for each command (used in signal and debug).
const CMD_NAMES: Dictionary = {
	Cmd.STOP: "stop",
	Cmd.HOLD: "hold",
	Cmd.ATTACK_MOVE: "attack_move",
	Cmd.PATROL: "patrol",
	Cmd.REPAIR: "repair",
	Cmd.GATHER: "gather",
	Cmd.RETURN_RESOURCE: "return_resource",
	Cmd.MOVE: "move",
	Cmd.ATTACK: "attack",
}

# =============================================================================
# State
# =============================================================================

var _patrol_mode: bool = false
var _patrol_point_a: Vector2 = Vector2.ZERO
var _patrol_click_count: int = 0

## Cached references (set by GameWorld after _ready).
var selection_manager: Node = null
var unit_manager: Node = null

# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	EventBus.button_pressed.connect(_on_button_pressed)


func setup(sel_mgr: Node, unt_mgr: Node) -> void:
	selection_manager = sel_mgr
	unit_manager = unt_mgr

# =============================================================================
# Command Dispatch
# =============================================================================

func _on_button_pressed(button_name: String, player_id: int) -> void:
	if player_id != GameManager.local_player_id:
		return

	match button_name:
		"stop_command":
			cmd_stop()
		"hold_position_command":
			cmd_hold_position()
		"attack_move_command":
			cmd_attack_move()
		"patrol_command":
			cmd_patrol()
		"repair_command":
			cmd_repair()
		"return_resource_command":
			cmd_return_resource()
		"gather_wood":
			cmd_gather("wood")
		"gather_food":
			cmd_gather("food")
		"gather_stone":
			cmd_gather("stone")
		"gather_gold":
			cmd_gather("gold")

# =============================================================================
# Command API
# =============================================================================

func cmd_stop() -> void:
	var ids: Array = _selected_ids()
	_apply_to_selected(func(unit: Node2D) -> void:
		_clear_unit_pending(unit)
		var mc: Node = unit.get_node_or_null("MovementComponent")
		if mc != null and mc.has_method("stop"):
			mc.stop()
		unit.set("hold_position", false)
		_change_state(unit, "IdleState")
	)
	unit_command.emit(CMD_NAMES[Cmd.STOP], ids, {})


func cmd_hold_position() -> void:
	var ids: Array = _selected_ids()
	_apply_to_selected(func(unit: Node2D) -> void:
		var mc: Node = unit.get_node_or_null("MovementComponent")
		if mc != null and mc.has_method("stop"):
			mc.stop()
		_clear_unit_pending(unit)
		_change_state(unit, "HoldState")
	)
	unit_command.emit(CMD_NAMES[Cmd.HOLD], ids, {})


func cmd_attack_move() -> void:
	var ids: Array = _selected_military_ids()
	_apply_to_selected_military(func(unit: Node2D) -> void:
		_change_state(unit, "AttackMoveState")
	)
	unit_command.emit(CMD_NAMES[Cmd.ATTACK_MOVE], ids, {})


func cmd_patrol() -> void:
	_patrol_mode = true
	_patrol_click_count = 0
	EventBus.menu_opened.emit("patrol_mode")
	unit_command.emit(CMD_NAMES[Cmd.PATROL], _selected_ids(), {"phase": "awaiting_click"})


func complete_patrol(world_pos: Vector2) -> void:
	if not _patrol_mode:
		return

	_patrol_click_count += 1
	if _patrol_click_count == 1:
		_patrol_point_a = world_pos
		unit_command.emit(CMD_NAMES[Cmd.PATROL], _selected_ids(), {"phase": "point_a_set", "point_a": world_pos})
		return

	_patrol_mode = false
	var point_a: Vector2 = _patrol_point_a
	var point_b: Vector2 = world_pos
	var ids: Array = _selected_military_ids()

	_apply_to_selected_military(func(unit: Node2D) -> void:
		unit.set("patrol_point_a", point_a)
		unit.set("patrol_point_b", point_b)
		_change_state(unit, "PatrolState")
	)

	_patrol_point_a = Vector2.ZERO
	_patrol_click_count = 0
	EventBus.menu_closed.emit("patrol_mode")
	unit_command.emit(CMD_NAMES[Cmd.PATROL], ids, {"point_a": point_a, "point_b": point_b})


func cancel_patrol() -> void:
	_patrol_mode = false
	_patrol_click_count = 0
	_patrol_point_a = Vector2.ZERO
	EventBus.menu_closed.emit("patrol_mode")


func cmd_repair() -> void:
	var ids: Array = _selected_villager_ids()
	_apply_to_selected_villagers(func(unit: Node2D) -> void:
		_change_state(unit, "RepairState")
	)
	unit_command.emit(CMD_NAMES[Cmd.REPAIR], ids, {})


func cmd_return_resource() -> void:
	var ids: Array = _selected_villager_ids()
	_apply_to_selected_villagers(func(unit: Node2D) -> void:
		var hc: Node = unit.get_node_or_null("HarvestComponent")
		if hc == null:
			return
		var carry: int = int(hc.get("current_carry")) if hc.get("current_carry") != null else 0
		if carry <= 0:
			return
		_change_state(unit, "ReturnResourceState")
	)
	unit_command.emit(CMD_NAMES[Cmd.RETURN_RESOURCE], ids, {})


func cmd_gather(resource_type: String) -> void:
	var ids: Array = _selected_villager_ids()
	_apply_to_selected_villagers(func(unit: Node2D) -> void:
		unit.set("preferred_resource", resource_type)
		var hc: Node = unit.get_node_or_null("HarvestComponent")
		if hc != null and hc.has_method("find_nearest_resource"):
			var target: Node2D = hc.find_nearest_resource(resource_type)
			if target != null:
				unit.set("pending_target_resource", target)
				_change_state(unit, "HarvestState")
	)
	unit_command.emit(CMD_NAMES[Cmd.GATHER], ids, {"resource_type": resource_type})

# =============================================================================
# Queries
# =============================================================================

func is_patrol_mode() -> bool:
	return _patrol_mode

# =============================================================================
# Internals — iteration helpers
# =============================================================================

func _apply_to_selected(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for uid: int in selection_manager.get_selected_units():
		var u: Node2D = unit_manager.get_unit(uid)
		if u != null and is_instance_valid(u):
			callback.call(u)


func _apply_to_selected_military(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for uid: int in selection_manager.get_selected_units():
		var u: Node2D = unit_manager.get_unit(uid)
		if u == null or not is_instance_valid(u):
			continue
		var ut: String = u.get("unit_type") if u.get("unit_type") != null else ""
		if ut.begins_with("villager"):
			continue
		callback.call(u)


func _apply_to_selected_villagers(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for uid: int in selection_manager.get_selected_units():
		var u: Node2D = unit_manager.get_unit(uid)
		if u == null or not is_instance_valid(u):
			continue
		var ut: String = u.get("unit_type") if u.get("unit_type") != null else ""
		if not ut.begins_with("villager"):
			continue
		callback.call(u)


func _selected_ids() -> Array:
	if selection_manager == null:
		return []
	return selection_manager.get_selected_units()


func _selected_military_ids() -> Array:
	if selection_manager == null or unit_manager == null:
		return []
	var result: Array = []
	for uid: int in selection_manager.get_selected_units():
		var u: Node2D = unit_manager.get_unit(uid)
		if u == null or not is_instance_valid(u):
			continue
		var ut: String = u.get("unit_type") if u.get("unit_type") != null else ""
		if not ut.begins_with("villager"):
			result.append(uid)
	return result


func _selected_villager_ids() -> Array:
	if selection_manager == null or unit_manager == null:
		return []
	var result: Array = []
	for uid: int in selection_manager.get_selected_units():
		var u: Node2D = unit_manager.get_unit(uid)
		if u == null or not is_instance_valid(u):
			continue
		var ut: String = u.get("unit_type") if u.get("unit_type") != null else ""
		if ut.begins_with("villager"):
			result.append(uid)
	return result

# =============================================================================
# Internals — unit helpers
# =============================================================================

func _clear_unit_pending(unit: Node2D) -> void:
	unit.set("pending_move_position", Vector2.ZERO)
	unit.set("pending_target_resource", null)
	unit.set("pending_target_building", null)
	unit.set("hold_position", false)


func _change_state(unit: Node2D, state_name: String) -> void:
	var sm: Node = unit.get_node_or_null("UnitStateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.change_state(state_name)
