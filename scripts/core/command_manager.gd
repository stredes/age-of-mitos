## Centralized command dispatcher. Listens to EventBus.button_pressed and
## translates high-level commands (stop, hold, patrol, attack-move, gather, etc.)
## into concrete state changes on selected units.
##
## Attach as a child of GameWorld. Replaces the scattered command handling
## previously spread across game_world.gd and input_manager.gd.
class_name CommandManager
extends Node

# =============================================================================
# State
# =============================================================================

## The patrol mode stores two click positions to form waypoints.
var _patrol_mode: bool = false
var _patrol_point_a: Vector2 = Vector2.ZERO
var _patrol_click_count: int = 0

## The attack-move mode waits for a destination click.
var _attack_move_mode: bool = false

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
		"build_menu":
			# Forward to GameWorld's build menu handler.
			pass
		_:
			if button_name.begins_with("train_"):
				pass  # Handled by GameWorld.

# =============================================================================
# Command API — called by GameWorld and InputManager
# =============================================================================

## Stop all selected units immediately.
func cmd_stop() -> void:
	_apply_to_selected(func(unit: Node2D) -> void:
		_clear_unit_pending(unit)
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and move_comp.has_method("stop"):
			move_comp.stop()
		unit.set("hold_position", false)
		_change_state(unit, "IdleState")
	)


## Hold position: stop and attack enemies in range, never chase.
func cmd_hold_position() -> void:
	_apply_to_selected(func(unit: Node2D) -> void:
		var move_comp: Node = unit.get_node_or_null("MovementComponent")
		if move_comp != null and move_comp.has_method("stop"):
			move_comp.stop()
		_clear_unit_pending(unit)
		_change_state(unit, "HoldState")
	)


## Attack-move: advance to cursor position, engaging enemies along the way.
func cmd_attack_move() -> void:
	_apply_to_selected_military(func(unit: Node2D) -> void:
		_change_state(unit, "AttackMoveState")
	)


## Patrol: set waypoints on selected units and start patrolling.
func cmd_patrol() -> void:
	_patrol_mode = true
	_patrol_click_count = 0
	EventBus.menu_opened.emit("patrol_mode")


## Complete the patrol command with the given world position.
func complete_patrol(world_pos: Vector2) -> void:
	if not _patrol_mode:
		return

	_patrol_click_count += 1
	if _patrol_click_count == 1:
		_patrol_point_a = world_pos
		# Wait for second click for point B.
		return

	# Second click — execute patrol.
	_patrol_mode = false
	var point_a: Vector2 = _patrol_point_a
	var point_b: Vector2 = world_pos

	_apply_to_selected_military(func(unit: Node2D) -> void:
		unit.set("patrol_point_a", point_a)
		unit.set("patrol_point_b", point_b)
		_change_state(unit, "PatrolState")
	)

	_patrol_point_a = Vector2.ZERO
	_patrol_click_count = 0
	EventBus.menu_closed.emit("patrol_mode")


## Cancel patrol mode.
func cancel_patrol() -> void:
	_patrol_mode = false
	_patrol_click_count = 0
	_patrol_point_a = Vector2.ZERO
	EventBus.menu_closed.emit("patrol_mode")


## Return carried resources to drop-off, then resume harvesting.
func cmd_return_resource() -> void:
	_apply_to_selected_villagers(func(unit: Node2D) -> void:
		var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
		if harvest_comp == null:
			return
		var carry: int = int(harvest_comp.get("current_carry")) if harvest_comp.get("current_carry") != null else 0
		if carry <= 0:
			return
		_change_state(unit, "ReturnResourceState")
	)


## Assign selected villagers to gather a resource type.
func cmd_gather(resource_type: String) -> void:
	_apply_to_selected_villagers(func(unit: Node2D) -> void:
		unit.set("preferred_resource", resource_type)
		var harvest_comp: Node = unit.get_node_or_null("HarvestComponent")
		if harvest_comp != null and harvest_comp.has_method("find_nearest_resource"):
			var target: Node2D = harvest_comp.find_nearest_resource(resource_type)
			if target != null:
				unit.set("pending_target_resource", target)
				_change_state(unit, "HarvestState")
	)

# =============================================================================
# Queries
# =============================================================================

## Returns true if we are waiting for patrol waypoint clicks.
func is_patrol_mode() -> bool:
	return _patrol_mode


## Returns true if we are waiting for attack-move destination.
func is_attack_move_mode() -> bool:
	return _attack_move_mode

# =============================================================================
# Internals
# =============================================================================

func _apply_to_selected(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit != null and is_instance_valid(unit):
			callback.call(unit)


func _apply_to_selected_military(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null or not is_instance_valid(unit):
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if utype.begins_with("villager"):
			continue
		callback.call(unit)


func _apply_to_selected_villagers(callback: Callable) -> void:
	if selection_manager == null or unit_manager == null:
		return
	for unit_id: int in selection_manager.get_selected_units():
		var unit: Node2D = unit_manager.get_unit(unit_id)
		if unit == null or not is_instance_valid(unit):
			continue
		var utype: String = unit.get("unit_type") if unit.get("unit_type") != null else ""
		if not utype.begins_with("villager"):
			continue
		callback.call(unit)


func _clear_unit_pending(unit: Node2D) -> void:
	unit.set("pending_move_position", Vector2.ZERO)
	unit.set("pending_target_resource", null)
	unit.set("pending_target_building", null)
	unit.set("hold_position", false)


func _change_state(unit: Node2D, state_name: String) -> void:
	var sm: Node = unit.get_node_or_null("UnitStateMachine")
	if sm != null and sm.has_method("change_state"):
		sm.change_state(state_name)
