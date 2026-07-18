class_name RepairState
extends UnitState

enum Phase {
	FIND_TARGET,
	GO_TO_BUILDING,
	REPAIRING,
}

var phase: Phase = Phase.FIND_TARGET

var target_building: Node2D = null
var _repair_timer: float = 0.0
const REPAIR_INTERVAL: float = 1.0
const REPAIR_RANGE: float = 48.0
const SEARCH_RANGE: float = 300.0
const REPAIR_AMOUNT: int = 5


func enter() -> void:
	_repair_timer = 0.0

	if unit == null:
		state_machine.change_state("IdleState")
		return

	if unit.pending_target_building != null:
		target_building = unit.pending_target_building
		unit.pending_target_building = null
		if _is_valid_repair_target(target_building):
			phase = Phase.GO_TO_BUILDING
			_move_to_building()
			return

	_find_damaged_building()


func update(delta: float) -> void:
	if target_building == null or not is_instance_valid(target_building):
		phase = Phase.FIND_TARGET
		_find_damaged_building()
		return

	match phase:
		Phase.FIND_TARGET:
			_find_damaged_building()

		Phase.GO_TO_BUILDING:
			if not _is_valid_repair_target(target_building):
				phase = Phase.FIND_TARGET
				target_building = null
				return

			var dist: float = unit.global_position.distance_to(target_building.global_position)
			if dist <= REPAIR_RANGE:
				var move_comp: Node = unit.get_node_or_null("MovementComponent")
				if move_comp != null and move_comp.is_moving:
					move_comp.stop()
				phase = Phase.REPAIRING
				_play_repair_anim()
			else:
				var move_comp: Node = unit.get_node_or_null("MovementComponent")
				if move_comp != null and not move_comp.is_moving:
					_move_to_building()

		Phase.REPAIRING:
			if not _is_valid_repair_target(target_building):
				phase = Phase.FIND_TARGET
				target_building = null
				return

			var dist: float = unit.global_position.distance_to(target_building.global_position)
			if dist > REPAIR_RANGE:
				phase = Phase.GO_TO_BUILDING
				_move_to_building()
				return

			_repair_timer += delta
			if _repair_timer >= REPAIR_INTERVAL:
				_repair_timer = 0.0
				_do_repair()


func exit() -> void:
	target_building = null
	_repair_timer = 0.0
	phase = Phase.FIND_TARGET


func _find_damaged_building() -> void:
	var buildings: Array[Node] = get_tree().get_nodes_in_group("buildings")
	var best: Node2D = null
	var best_dist: float = SEARCH_RANGE

	for b: Node in buildings:
		if b == null or not is_instance_valid(b):
			continue
		if not b is BuildingBase:
			continue
		if b.player_id != unit.player_id:
			continue
		if not b.is_constructed:
			continue
		if b.current_hp >= b.max_hp:
			continue

		var dist: float = unit.global_position.distance_to(b.global_position)
		if dist < best_dist:
			best_dist = dist
			best = b as Node2D

	if best != null:
		target_building = best
		phase = Phase.GO_TO_BUILDING
		_move_to_building()
	else:
		state_machine.change_state("IdleState")


func _is_valid_repair_target(b: Node2D) -> bool:
	if b == null or not is_instance_valid(b):
		return false
	if not b is BuildingBase:
		return false
	if b.player_id != unit.player_id:
		return false
	if not b.is_constructed:
		return false
	if b.current_hp >= b.max_hp:
		return false
	return true


func _do_repair() -> void:
	if target_building == null or not is_instance_valid(target_building):
		return

	if target_building.has_method("heal"):
		target_building.heal(REPAIR_AMOUNT)
	_play_repair_anim()

	if target_building.current_hp >= target_building.max_hp:
		state_machine.change_state("IdleState")


func _move_to_building() -> void:
	if target_building == null or unit == null:
		return

	var move_comp: Node = unit.get_node_or_null("MovementComponent")
	if move_comp != null:
		move_comp.move_to(target_building.global_position)

	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		var dir: Vector2 = (target_building.global_position - unit.global_position).normalized()
		anim.play_state("walk", dir)


func _play_repair_anim() -> void:
	var anim: Node = _get_anim_controller()
	if anim != null and anim.has_method("play_state"):
		anim.play_state("build")


func _get_anim_controller() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("UnitAnimationController")
